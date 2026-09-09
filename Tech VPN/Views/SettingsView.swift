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

    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showDeleteConfirmAlert = false
    @State private var isDeletingAccount = false
    @State private var showLoginSheet = false
    @State private var showSubscription = false
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

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
                                if subscriptionManager.isProUser {
                                    // Pro users see status only — no upgrade prompt
                                    HStack {
                                        Text("Subscription")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#E4E2E1"))
                                        Spacer()
                                        HStack(spacing: 5) {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 11))
                                            Text("PRO")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundColor(Color(hex: "#f1c40f"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#f1c40f").opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .frame(height: 56)
                                    .padding(.horizontal, 16)
                                } else {
                                    Button(action: { showSubscription = true }) {
                                        SettingsNavRow(title: "Subscription", value: "Free")
                                    }
                                }
                                settingsDivider
                                SettingsNavRow(title: "Email", value: authService.profile?.email ?? authService.currentUser?.email ?? "")
                                settingsDivider
                                SettingsNavRow(title: "Username", value: authService.profile?.username ?? authService.currentUser?.username ?? "—")
                            }
                        }
                    }

                    // Connection Section
                    settingsSection(title: "CONNECTION") {
                        VStack(spacing: 0) {
                            SettingsNavRow(title: "VPN Protocol", value: "IKEv2")
                            settingsDivider
                            SettingsToggleRow(title: "Auto-Connect", isOn: Binding(
                                get: { vpnManager.autoConnectEnabled },
                                set: { vpnManager.autoConnectEnabled = $0 }
                            ))
                            settingsDivider
                            if subscriptionManager.isProUser {
                                SettingsToggleRow(title: "Kill Switch", isOn: Binding(
                                    get: { vpnManager.killSwitchEnabled },
                                    set: { vpnManager.updateKillSwitch(enabled: $0) }
                                ))
                            } else {
                                Button(action: { showSubscription = true }) {
                                    HStack {
                                        Text("Kill Switch")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#E4E2E1"))
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#f1c40f"))
                                            Text("PRO")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color(hex: "#f1c40f"))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#f1c40f").opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .frame(height: 56)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }

                    // Preferences Section
                    settingsSection(title: "PREFERENCES") {
                        VStack(spacing: 0) {
                            SettingsNavRow(title: "Language", value: "English")
                        }
                    }

                    // Support Section
                    settingsSection(title: "SUPPORT") {
                        VStack(spacing: 0) {
                            Button(action: {
                                if let url = URL(string: "mailto:business@xylosolution.com") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsNavRow(title: "Help Center", value: nil)
                            }
                            settingsDivider
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/privacy-policy-2/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsNavRow(title: "Privacy Policy", value: nil)
                            }
                            settingsDivider
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/terms-of-service/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                SettingsNavRow(title: "Terms of Service", value: nil)
                            }
                            settingsDivider
                            SettingsNavRow(title: "About", value: "Version 1.0.0")
                            settingsDivider
                            Button(action: handleRestorePurchases) {
                                HStack {
                                    Text("Restore Purchases")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#E4E2E1"))
                                    Spacer()
                                    if isRestoring {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(AppTheme.Colors.secondary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
                                    }
                                }
                                .frame(height: 56)
                                .padding(.horizontal, 16)
                            }
                            .disabled(isRestoring)

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

                        // Delete account — destructive, shown only for logged-in users
                        Button(action: { showDeleteAlert = true }) {
                            HStack(spacing: 8) {
                                if isDeletingAccount {
                                    ProgressView()
                                        .tint(.red)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14))
                                }
                                Text(isDeletingAccount ? "Deleting..." : "DELETE ACCOUNT")
                                    .font(.system(size: 15, weight: .bold))
                                    .tracking(1)
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                        }
                        .disabled(isDeletingAccount)
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        .padding(.top, 4)
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
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                showDeleteConfirmAlert = true
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showDeleteConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Yes, Delete Everything", role: .destructive) {
                handleDeleteAccount()
            }
        } message: {
            Text("Your profile, connection history, and settings will be permanently removed. Your VPN subscription will not be automatically cancelled — please cancel it in your App Store subscriptions.")
        }
        .task {
            if !isGuestMode {
                await authService.fetchProfile()
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheet(authService: authService, isGuestMode: $isGuestMode)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert(restoreMessage.contains("✓") ? "Purchases Restored" : "Restore Failed",
               isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
    }

    // MARK: - Restore Purchases Handler
    private func handleRestorePurchases() {
        isRestoring = true
        Task {
            let success = await subscriptionManager.restorePurchases()
            await MainActor.run {
                isRestoring = false
                if success {
                    restoreMessage = "✓ Your Pro subscription has been restored successfully."
                } else {
                    restoreMessage = "No active subscription was found for your Apple ID. If you believe this is an error, please contact support at business@xylosolution.com"
                }
                showRestoreAlert = true
            }
        }
    }

    // MARK: - Delete Account Handler
    private func handleDeleteAccount() {
        isDeletingAccount = true
        if vpnManager.isConnected {
            vpnManager.disconnect()
        }
        Task {
            let success = await authService.deleteAccount()
            await MainActor.run {
                isDeletingAccount = false
                if !success {
                    // Fallback: just log out locally if deletion call failed
                    authService.logout()
                }
            }
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
            Text(subscriptionManager.isProUser ? "PRO" : "FREE")
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
                // "Continue without account" tapped
                isGuestMode = false
                dismiss()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        // Auto-dismiss as soon as authentication succeeds (login OR signup)
        .onChange(of: authService.isAuthenticated) { authenticated in
            if authenticated {
                isGuestMode = false
                dismiss()
            }
        }
    }
}
