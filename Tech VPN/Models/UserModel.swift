//
//  UserModel.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation

struct Profile: Codable {
    let id: UUID
    let username: String
    let email: String
    let subscriptionStatus: String?
    let subscriptionExpiresAt: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username, email
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}


struct ConnectionLog: Codable {
    var id: Int?
    let userId: UUID
    let serverId: Int
    var connectedAt: String?
    var disconnectedAt: String?
    var durationSeconds: Int?
    var bytesSent: Int64?
    var bytesReceived: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case serverId = "server_id"
        case connectedAt = "connected_at"
        case disconnectedAt = "disconnected_at"
        case durationSeconds = "duration_seconds"
        case bytesSent = "bytes_sent"
        case bytesReceived = "bytes_received"
    }
}

// Legacy compatibility (used by old code paths)
struct User: Codable {
    let id: String
    let username: String
    let email: String
}

struct ErrorResponse: Codable {
    let error: String
}
