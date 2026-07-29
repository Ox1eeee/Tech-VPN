//
//  ServerModel.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation

struct VPNServer: Identifiable, Codable {
    let id: Int
    let name: String
    let country: String
    let ipAddress: String
    let load: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case country
        case ipAddress = "ip_address"
        case load
    }
    
    var flagEmoji: String {
        let countryFlags: [String: String] = [
            "US": "🇺🇸", "UK": "🇬🇧", "DE": "🇩🇪", "FR": "🇫🇷",
            "JP": "🇯🇵", "SG": "🇸🇬", "AU": "🇦🇺", "CA": "🇨🇦",
            "NL": "🇳🇱", "IN": "🇮🇳", "BR": "🇧🇷", "KR": "🇰🇷"
        ]
        return countryFlags[country.uppercased()] ?? "🌐"
    }
    
    var loadColor: String {
        if load < 30 { return "green" }
        else if load < 70 { return "yellow" }
        else { return "red" }
    }
}

struct VPNServerConfig: Codable {
    let serverAddress: String
    let remoteIdentifier: String
    let certificate: String?
    let presharedKey: String?
}
