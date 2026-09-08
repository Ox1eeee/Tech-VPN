//
//  APIService.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import Network
import Supabase

class APIService {
    static let shared = APIService()
    private let supabase = SupabaseManager.shared.client
    
    /// Server list API endpoint (hosted on techvpnpro.com)
    private let serverListURL = "https://techvpnpro.com/api/servers.json"
    
    /// Cached server list (populated from API or fallback)
    private(set) var cachedServers: [VPNServer] = []
    
    private init() {}
    
    // MARK: - Fetch Server List (from techvpnpro.com)
    func fetchServers() async throws -> [VPNServer] {
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
        cachedServers = servers
        return servers
    }
    
    // MARK: - Fetch Server Config
    func fetchServerConfig(serverId: Int) async throws -> VPNServerConfig {
        guard let server = cachedServers.first(where: { $0.id == serverId }) else {
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
        return cachedServers.first(where: { $0.id == serverId })?.name ?? "Server \(serverId)"
    }
    
    // MARK: - Latency Measurement
    /// Measures TCP handshake latency to a server (port 443). Returns milliseconds, or .infinity on failure.
    func measureLatency(for server: VPNServer) async -> Double {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(server.ipAddress)
            let port = NWEndpoint.Port(integerLiteral: 443)
            let connection = NWConnection(host: host, port: port, using: .tcp)
            let start = CFAbsoluteTimeGetCurrent()
            var resumed = false
            
            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    connection.cancel()
                    continuation.resume(returning: ms)
                case .failed, .cancelled:
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: Double.infinity)
                default:
                    break
                }
            }
            
            connection.start(queue: DispatchQueue(label: "latency.\(server.id)"))
            
            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: Double.infinity)
            }
        }
    }
    
    /// Finds the server with the lowest latency from a list
    func findFastestServer(from servers: [VPNServer]) async -> VPNServer? {
        guard !servers.isEmpty else { return nil }
        
        var results: [(VPNServer, Double)] = []
        
        await withTaskGroup(of: (VPNServer, Double).self) { group in
            for server in servers {
                group.addTask {
                    let latency = await self.measureLatency(for: server)
                    return (server, latency)
                }
            }
            for await result in group {
                results.append(result)
            }
        }
        
        return results
            .filter { $0.1 < Double.infinity }
            .min(by: { $0.1 < $1.1 })?
            .0 ?? servers.first
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
