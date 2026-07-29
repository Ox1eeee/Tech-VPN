//
//  APIService.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation

class APIService {
    static let shared = APIService()
    private init() {}
    
    // MARK: - Base URL (change this to your backend server)
    private var baseURL = "http://148.113.44.176:3000"
    
    private var authToken: String? {
        return KeychainHelper.shared.readString(forKey: KeychainHelper.tokenKey)
    }
    
    // MARK: - Generic Request
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Fetch Server List
    func fetchServers() async throws -> [VPNServer] {
        return try await request(endpoint: "/api/servers")
    }
    
    // MARK: - Fetch Server Config
    func fetchServerConfig(serverId: Int) async throws -> VPNServerConfig {
        return try await request(
            endpoint: "/api/vpn/config/\(serverId)",
            requiresAuth: true
        )
    }
    
    // MARK: - Log Connection
    func logConnection(serverId: Int) async throws -> ConnectionLogResponse {
        return try await request(
            endpoint: "/api/vpn/connect",
            method: "POST",
            body: ["serverId": serverId],
            requiresAuth: true
        )
    }
    
    // MARK: - Log Disconnection
    func logDisconnection(connectionId: Int) async throws {
        let _: ConnectionLogResponse = try await request(
            endpoint: "/api/vpn/disconnect",
            method: "POST",
            body: ["connectionId": connectionId],
            requiresAuth: true
        )
    }
    
    // MARK: - Fetch Usage Stats
    func fetchUsageStats() async throws -> UsageStats {
        return try await request(endpoint: "/api/stats/usage", requiresAuth: true)
    }
    
    // MARK: - Fetch Security Audit
    func fetchSecurityAudit() async throws -> SecurityAudit {
        return try await request(endpoint: "/api/stats/security", requiresAuth: true)
    }
    
    // MARK: - Fetch User Profile
    func fetchProfile() async throws -> UserProfile {
        return try await request(endpoint: "/api/account/profile", requiresAuth: true)
    }
    
    // MARK: - Update Base URL
    func updateBaseURL(_ url: String) {
        // For future use if user wants to configure server URL
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
