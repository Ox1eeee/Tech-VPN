//
//  StatsModel.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation

struct UsageStats: Codable {
    let totalData: Int
    let totalSessions: Int
    let totalBytesSent: Int
    let totalBytesReceived: Int
    let timeProtected: Int
    let averageSpeed: Double
    let dailyData: [DailyDataEntry]

    struct DailyDataEntry: Codable {
        let date: String
        let sessions: Int
        let dataBytes: Int
    }
}

struct SecurityAudit: Codable {
    let auditLog: [AuditLogEntry]
}

struct AuditLogEntry: Codable {
    let id: Int
    let serverName: String?
    let serverCountry: String?
    let connectedAt: String?
    let disconnectedAt: String?
    let duration: Double
    let bytesSent: Int
    let bytesReceived: Int
    let encrypted: Bool
}

struct UserProfile: Codable {
    let id: Int
    let email: String
    let username: String
    let subscriptionStatus: String
    let createdAt: String
}
