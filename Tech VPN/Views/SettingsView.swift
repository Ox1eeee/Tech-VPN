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
    @Binding var isGuestMode: Bool

    @State private var autoConnect = false
    @State private var killSwitch = true
    @State private var notifications = true
    @State private var showLogoutAlert = false
    @State private var showLoginSheet = false
    @State private var showDebugLog = false

    var body: some View {
        ZStack {
            // Background with radial gradient
            RadialGradient(
                colors: [Color(hex: "#1a0808"), Color(hex: "#0A0A0A")],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Ambient glow
            Circle()
                .fill(AppTheme.Colors.primaryContainer.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 80)

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Profile Header or Guest Banner
                    if isGuestMode {
                        guestBanner
                    } else {
                        profileHeader
                    }

                    // Account Section (only for logged-in users)
                    if !isGuestMode {
                        settingsSection(title: "ACCOUNT") {
                            VStack(spacing: 0) {
                                SettingsNavRow(title: "Subscription", value: authService.profile?.subscriptionStatus?.capitalized ?? "Free")
                                settingsDivider
                                SettingsNavRow(title: "Email", value: authService.profile?.email ?? authService.currentUser?.email ?? "")
                                settingsDivider
                                SettingsNavRow(title: "Username", value: authService.profile?.username ?? authService.currentUser?.username ?? "—")
                                settingsDivider
                                SettingsNavRow(title: "Billing History", value: nil)
                            }
                        }
                    }

                    // Connection Section
                    settingsSection(title: "CONNECTION") {
                        VStack(spacing: 0) {
                            SettingsNavRow(title: "VPN Protocol", value: "IKEv2")
                            settingsDivider
                            SettingsToggleRow(title: "Auto-Connect", isOn: $autoConnect)
                            settingsDivider
                            SettingsToggleRow(title: "Kill Switch", isOn: $killSwitch)
                            settingsDivider
                            SettingsNavRow(title: "Split Tunneling", value: nil)
                        }
                    }

                    // Preferences Section
                    settingsSection(title: "PREFERENCES") {
                        VStack(spacing: 0) {
                            SettingsNavRow(title: "Appearance", value: "Dark")
                            settingsDivider
                            SettingsNavRow(title: "Language", value: "English")
                            settingsDivider
                            SettingsToggleRow(title: "Notifications", isOn: $notifications)
                        }
                    }

                    // Support Section
                    settingsSection(title: "SUPPORT") {
                        VStack(spacing: 0) {
                            SettingsNavRow(title: "Help Center", value: nil)
                            settingsDivider
                            SettingsNavRow(title: "Privacy Policy", value: nil)
                            settingsDivider
                            SettingsNavRow(title: "Terms of Service", value: nil)
                            settingsDivider
                            SettingsNavRow(title: "About", value: "Version 1.0.0")
                            settingsDivider
                            Button(action: { showDebugLog = true }) {
                                SettingsNavRow(title: "Debug Log", value: nil)
                            }
                        }
                    }

                    // Logout / Login Button
                    if isGuestMode {
                        Button(action: { showLoginSheet = true }) {
                            Text("LOG IN / SIGN UP")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(2)
                                .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.md)
                                .background(AppTheme.Colors.primaryContainer)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.3), radius: 20)
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        .padding(.top, AppTheme.Spacing.sm)
                    } else {
                        Button(action: { showLogoutAlert = true }) {
                            Text("LOG OUT")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(2)
                                .foregroundColor(AppTheme.Colors.primaryContainer)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.md)
                                .background(Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.Colors.primaryContainer.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        .padding(.top, AppTheme.Spacing.sm)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, AppTheme.Spacing.lg)
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
            if !isGuestMode {
                await authService.fetchProfile()
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheet(authService: authService, isGuestMode: $isGuestMode)
        }
        .sheet(isPresented: $showDebugLog) {
            DebugLogView(vpnManager: vpnManager)
        }
    }

    // MARK: - Guest Banner
    private var guestBanner: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(AppTheme.Colors.primaryContainer.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.Colors.primaryContainer)
                )
                .padding(.bottom, AppTheme.Spacing.sm)

            Text("Guest Mode")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#E4E2E1"))

            Text("You're browsing without an account. Sign up to sync your settings and connection history.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, AppTheme.Spacing.sm)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#291714"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 0) {
            // Avatar
            Circle()
                .fill(AppTheme.Colors.primaryContainer.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.Colors.primaryContainer)
                )
                .padding(.bottom, AppTheme.Spacing.sm)

            // Username
            Text(authService.profile?.username ?? authService.currentUser?.username ?? "User")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#E4E2E1"))
                .multilineTextAlignment(.center)

            // Email
            Text(authService.profile?.email ?? authService.currentUser?.email ?? "")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.bottom, AppTheme.Spacing.sm)

            // Subscription Badge
            Text((authService.profile?.subscriptionStatus ?? "free").uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(AppTheme.Colors.primaryContainer)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.primaryContainer.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#291714"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
    }

    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundColor(AppTheme.Colors.secondary.opacity(0.8))
                .padding(.leading, AppTheme.Spacing.safeMargin + 16)

            content()
                .background(Color(hex: "#1F2020"))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
                .foregroundColor(Color(hex: "#E4E2E1"))

            Spacer()

            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
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
                .foregroundColor(Color(hex: "#E4E2E1"))

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(AppTheme.Colors.primaryContainer)
                .labelsHidden()
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }
}

#Preview {
    SettingsView(authService: AuthService.shared, vpnManager: VPNManager(), isGuestMode: .constant(false))
}

// MARK: - Login Sheet (for guest users)
private struct LoginSheet: View {
    @ObservedObject var authService: AuthService
    @Binding var isGuestMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            LoginView(authService: authService) {
                isGuestMode = false
                dismiss()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}
