//
//  SettingsView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var vpnManager: VPNManager
    
    @State private var autoConnect = true
    @State private var killSwitch = true
    @State private var showLogoutAlert = false
    @State private var profile: UserProfile?
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                settingsTopBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Account Section
                        settingsSection(title: "ACCOUNT") {
                            VStack(spacing: 0) {
                                SettingsNavRow(title: "Subscription", value: profile?.subscriptionStatus.capitalized ?? "Free")
                                settingsDivider
                                SettingsNavRow(
                                    title: "Email",
                                    value: profile?.email ?? authService.currentUser?.email ?? KeychainHelper.shared.readString(forKey: KeychainHelper.usernameKey) ?? "user@techvpn.io"
                                )
                                settingsDivider
                                SettingsNavRow(title: "Username", value: profile?.username ?? authService.currentUser?.username ?? "—")
                                settingsDivider
                                SettingsNavRow(title: "Billing History", value: nil)
                            }
                        }
                        
                        // Connection Section
                        settingsSection(title: "CONNECTION") {
                            VStack(spacing: 0) {
                                SettingsToggleRow(title: "Auto-Connect", isOn: $autoConnect)
                                settingsDivider
                                SettingsNavRow(title: "VPN Protocol", value: "IKEv2")
                                settingsDivider
                                SettingsNavRow(title: "Split Tunneling", value: nil)
                            }
                        }
                        
                        // Security Section
                        settingsSection(title: "SECURITY") {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.primaryContainer)
                                    
                                    Text("Kill Switch")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.onSurface)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $killSwitch)
                                        .tint(AppTheme.Colors.primaryContainer)
                                        .labelsHidden()
                                }
                                .padding(16)
                                
                                settingsDivider
                                SettingsNavRow(title: "Threat Protection", value: nil)
                                settingsDivider
                                SettingsNavRow(title: "Invisible on LAN", value: nil)
                            }
                        }
                        
                        // Logout Button
                        Button(action: { showLogoutAlert = true }) {
                            Text("LOG OUT")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                                .foregroundColor(AppTheme.Colors.primaryContainer)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AppTheme.Colors.surfaceContainer)
                                .cornerRadius(AppTheme.Radius.xl)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                                        .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Version
                        Text("TECH VPN v1.0.0")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppTheme.Spacing.sm)
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, AppTheme.Spacing.md)
                }
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                if vpnManager.isConnected {
                    vpnManager.disconnect()
                }
                authService.logout()
            }
        } message: {
            Text("Are you sure you want to log out? Your VPN connection will be disconnected.")
        }
        .task {
            await fetchProfile()
        }
    }
    
    // MARK: - Fetch Profile
    private func fetchProfile() async {
        do {
            profile = try await APIService.shared.fetchProfile()
        } catch {
            print("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Top Bar
    private var settingsTopBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "shield")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("TECH VPN")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            Spacer()
            
            Circle()
                .fill(AppTheme.Colors.surfaceContainerHigh)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.secondary)
                )
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.outlineVariant.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
        .frame(height: 64)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundColor(AppTheme.Colors.secondary)
                .padding(.horizontal, AppTheme.Spacing.safeMargin + 16)
            
            content()
                .background(AppTheme.Colors.surfaceContainer)
                .cornerRadius(AppTheme.Radius.xl)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
        }
    }
    
    private var settingsDivider: some View {
        Rectangle()
            .fill(AppTheme.Colors.outlineVariant.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// MARK: - Settings Nav Row
struct SettingsNavRow: View {
    let title: String
    let value: String?
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.onSurface)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .padding(16)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.onSurface)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(AppTheme.Colors.primaryContainer)
                .labelsHidden()
        }
        .padding(16)
    }
}

#Preview {
    SettingsView(authService: AuthService.shared, vpnManager: VPNManager())
}
