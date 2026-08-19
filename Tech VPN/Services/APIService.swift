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
    
    private init() {}
    
    // MARK: - Server List
    // Each server uses a subdomain of techvpnpro.com with Let's Encrypt cert
    // remoteIdentifier must match the domain (leftid in ipsec.conf)
    private let vpnServers: [VPNServer] = [
        VPNServer(id: 1, name: "France #1", country: "FR", ipAddress: "fr1.techvpnpro.com", load: 10)
    ]
    
    // MARK: - Fetch Server List
    func fetchServers() async throws -> [VPNServer] {
        return vpnServers
    }
    
    // MARK: - Fetch Server Config
    func fetchServerConfig(serverId: Int) async throws -> VPNServerConfig {
        guard let server = vpnServers.first(where: { $0.id == serverId }) else {
            throw APIError.serverError("Server not found")
        }
        
        return VPNServerConfig(
            serverAddress: server.ipAddress,
            remoteIdentifier: server.ipAddress,
            certificate: nil,
            presharedKey: nil
        )
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
    func logDisconnection(serverId: Int, durationSeconds: Int) async throws {
        let session = try await supabase.auth.session
        let updatePayload = DisconnectUpdate(
            disconnectedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: durationSeconds
        )
        try await supabase
            .from("connection_logs")
            .update(updatePayload)
            .eq("user_id", value: session.user.id.uuidString)
            .eq("server_id", value: serverId)
            .is("disconnected_at", value: true)
            .execute()
    }
}

// MARK: - Update Payloads
private struct DisconnectUpdate: Codable {
    let disconnectedAt: String
    let durationSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case disconnectedAt = "disconnected_at"
        case durationSeconds = "duration_seconds"
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
