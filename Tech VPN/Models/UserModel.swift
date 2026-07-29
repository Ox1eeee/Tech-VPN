//
//  UserModel.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation

struct User: Codable {
    let id: Int
    let username: String
    let email: String
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct SignupResponse: Codable {
    let message: String
    let userId: Int
}

struct ErrorResponse: Codable {
    let error: String
}

struct ConnectionLogResponse: Codable {
    let message: String
    let connectionId: Int
}
