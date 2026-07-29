//
//  AuthService.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import SwiftUI
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let baseURL = "http://148.113.44.176:3000"
    private let keychain = KeychainHelper.shared
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Check if user is already logged in
    func checkAuthStatus() {
        if let token = keychain.readString(forKey: KeychainHelper.tokenKey), !token.isEmpty {
            isAuthenticated = true
        }
    }
    
    // MARK: - Sign Up
    func signup(email: String, username: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/api/auth/signup") else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = [
                "email": email,
                "username": username,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                // Auto-login after signup
                await login(username: username, password: password)
            } else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.httpError(httpResponse.statusCode)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Login
    func login(username: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/api/auth/login") else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = [
                "username": username,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
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
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Save token and credentials to Keychain
            keychain.save(string: authResponse.token, forKey: KeychainHelper.tokenKey)
            keychain.save(string: username, forKey: KeychainHelper.usernameKey)
            keychain.save(string: password, forKey: KeychainHelper.vpnPasswordKey)
            
            await MainActor.run {
                currentUser = authResponse.user
                isAuthenticated = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        keychain.delete(forKey: KeychainHelper.tokenKey)
        keychain.delete(forKey: KeychainHelper.usernameKey)
        keychain.delete(forKey: KeychainHelper.vpnPasswordKey)
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
}
