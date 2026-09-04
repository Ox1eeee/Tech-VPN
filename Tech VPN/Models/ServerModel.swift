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
    let countryCode: String
    let city: String?
    let ipAddress: String
    let load: Int
    let isActive: Bool
    let isPremium: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case country
        case countryCode = "country_code"
        case city
        case ipAddress = "ip_address"
        case load
        case isActive = "is_active"
        case isPremium = "is_premium"
    }
    
    init(id: Int, name: String, country: String, countryCode: String = "", city: String? = nil, ipAddress: String, load: Int, isActive: Bool = true, isPremium: Bool = false) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode.isEmpty ? country : countryCode
        self.city = city
        self.ipAddress = ipAddress
        self.load = load
        self.isActive = isActive
        self.isPremium = isPremium
    }
    
    var flagEmoji: String {
        let code = countryCode.isEmpty ? country : countryCode
        let countryFlags: [String: String] = [
            "US": "🇺🇸", "UK": "🇬🇧", "DE": "🇩🇪", "FR": "🇫🇷",
            "JP": "🇯🇵", "SG": "🇸🇬", "AU": "🇦🇺", "CA": "🇨🇦",
            "NL": "🇳🇱", "IN": "🇮🇳", "BR": "🇧🇷", "KR": "🇰🇷"
        ]
        return countryFlags[code.uppercased()] ?? "🌐"
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
