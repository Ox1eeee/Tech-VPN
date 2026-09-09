//
//  AuthService.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import RevenueCat

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var profile: Profile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    private init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Check if user is already logged in
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = User(
                    id: userId,
                    username: session.user.userMetadata["username"]?.value as? String ?? "",
                    email: session.user.email ?? ""
                )
            }
            await fetchProfile()
            await SubscriptionManager.shared.syncUserID(userId)
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Sign Up
    func signup(email: String, username: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["username": .string(username)]
            )
            
            if response.session != nil {
                let userId = response.user.id.uuidString
                await MainActor.run {
                    self.currentUser = User(
                        id: userId,
                        username: username,
                        email: email
                    )
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                await fetchProfile()
                await SubscriptionManager.shared.syncUserID(userId)
            } else {
                await MainActor.run {
                    self.errorMessage = "Please check your email to confirm your account."
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            let userId = session.user.id.uuidString
            await MainActor.run {
                self.currentUser = User(
                    id: userId,
                    username: session.user.userMetadata["username"]?.value as? String ?? "",
                    email: session.user.email ?? ""
                )
                self.isAuthenticated = true
                self.isLoading = false
            }
            await fetchProfile()
            await SubscriptionManager.shared.syncUserID(userId)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch Profile from Supabase
    func fetchProfile() async {
        do {
            let session = try await supabase.auth.session
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.profile = profile
            }
        } catch {
            print("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Logout
    func logout() {
        Task {
            try? await supabase.auth.signOut()
            await SubscriptionManager.shared.logOutUser()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.profile = nil
            }
        }
    }
}
