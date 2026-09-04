//
//  APIService.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import Supabase

class APIService {
    static let shared = APIService()
    private let supabase = SupabaseManager.shared.client
    
    /// Server list API endpoint (hosted on techvpnpro.com)
    private let serverListURL = "https://techvpnpro.com/api/servers.json"
    
    /// Cached server list (populated from API or fallback)
    private(set) var cachedServers: [VPNServer] = []
    
    private init() {}
    
    // MARK: - Fallback Server List
    // Used when API is unreachable (offline, first launch, etc.)
    private let fallbackServers: [VPNServer] = [
        VPNServer(id: 1, name: "France #1", country: "France", countryCode: "FR", city: "Paris", ipAddress: "fr1.techvpnpro.com", load: 10)
    ]
    
    // MARK: - Fetch Server List (from techvpnpro.com)
    func fetchServers() async throws -> [VPNServer] {
        do {
            guard let url = URL(string: serverListURL) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw APIError.invalidResponse
            }
            
            let servers = try JSONDecoder().decode([VPNServer].self, from: data)
            
            if !servers.isEmpty {
                cachedServers = servers
                return servers
            }
        } catch {
            print("Server list fetch failed: \(error.localizedDescription)")
        }
        
        // Fallback to hardcoded list
        cachedServers = fallbackServers
        return fallbackServers
    }
    
    // MARK: - Fetch Server Config
    func fetchServerConfig(serverId: Int) async throws -> VPNServerConfig {
        // Try cached servers first, then fallback
        let allServers = cachedServers.isEmpty ? fallbackServers : cachedServers
        guard let server = allServers.first(where: { $0.id == serverId }) else {
            throw APIError.serverError("Server not found")
        }
        
        return VPNServerConfig(
            serverAddress: server.ipAddress,
            remoteIdentifier: server.ipAddress,
            certificate: nil,
            presharedKey: nil
        )
    }
    
    // MARK: - Get server name by ID (for stats display)
    func serverName(for serverId: Int) -> String {
        let allServers = cachedServers.isEmpty ? fallbackServers : cachedServers
        return allServers.first(where: { $0.id == serverId })?.name ?? "Server \(serverId)"
    }
    
    // MARK: - Log Connection
    func logConnection(serverId: Int) async throws {
        let session = try await supabase.auth.session
        let log = ConnectionLog(
            userId: session.user.id,
            serverId: serverId
        )
        try await supabase
            .from("connection_logs")
            .insert(log)
            .execute()
    }
    
    // MARK: - Log Disconnection
    func logDisconnection(serverId: Int, durationSeconds: Int, bytesSent: Int64 = 0, bytesReceived: Int64 = 0) async throws {
        let session = try await supabase.auth.session
        let updatePayload = DisconnectUpdate(
            disconnectedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: durationSeconds,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived
        )
        try await supabase
            .from("connection_logs")
            .update(updatePayload)
            .eq("user_id", value: session.user.id.uuidString)
            .eq("server_id", value: serverId)
            .is("disconnected_at", value: nil)
            .order("connected_at", ascending: false)
            .limit(1)
            .execute()
    }
}

// MARK: - Update Payloads
private struct DisconnectUpdate: Codable {
    let disconnectedAt: String
    let durationSeconds: Int
    let bytesSent: Int64
    let bytesReceived: Int64
    
    enum CodingKeys: String, CodingKey {
        case disconnectedAt = "disconnected_at"
        case durationSeconds = "duration_seconds"
        case bytesSent = "bytes_sent"
        case bytesReceived = "bytes_received"
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case noToken
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .noToken:
            return "No authentication token"
        }
    }
}
