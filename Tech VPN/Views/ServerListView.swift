//
//  ServerListView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

struct ServerListView: View {
    @ObservedObject var vpnManager: VPNManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var servers: [VPNServer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var filteredServers: [VPNServer] {
        if searchText.isEmpty {
            return servers
        }
        return servers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                serverListTopBar
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.Colors.primaryContainer)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Search Bar
                            searchBar
                                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                                .padding(.top, AppTheme.Spacing.sm)
                            
                            // Recommended Section
                            recommendedSection
                                .padding(.top, AppTheme.Spacing.md)
                            
                            // All Locations
                            allLocationsSection
                                .padding(.top, AppTheme.Spacing.lg)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadServers()
        }
    }
    
    // MARK: - Top Bar
    private var serverListTopBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.primaryContainer)
                
                Text("TECH VPN")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Circle()
                    .fill(AppTheme.Colors.secondaryContainer)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                    )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
        .frame(height: 64)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.secondary.opacity(0.5))
            
            TextField("Search servers or countries", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.onSurface)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(AppTheme.Colors.surfaceContainerHigh)
        .cornerRadius(AppTheme.Radius.xl)
    }
    
    // MARK: - Recommended Section
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("RECOMMENDED")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(AppTheme.Colors.secondary)
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
            
            Button(action: {
                if let fastest = servers.min(by: { $0.load < $1.load }) {
                    selectServer(fastest)
                }
            }) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Bolt icon
                    Circle()
                        .fill(AppTheme.Colors.primaryContainer)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                        .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.3), radius: 15)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fastest Server")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                        
                        Text("Connect to the lowest latency node automatically")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Auto")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.success)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primaryContainer)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surfaceContainerLow)
                .cornerRadius(AppTheme.Radius.xl)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                        .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)
        }
    }
    
    // MARK: - All Locations
    private var allLocationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("ALL LOCATIONS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.Colors.secondary)
                
                Spacer()
                
                Text("FILTER")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.Colors.primaryContainer)
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)
            
            LazyVStack(spacing: AppTheme.Spacing.base) {
                ForEach(filteredServers) { server in
                    ServerRowView(
                        server: server,
                        isSelected: vpnManager.selectedServer?.id == server.id
                    ) {
                        selectServer(server)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)
        }
    }
    
    private func loadServers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedServers = try await APIService.shared.fetchServers()
                await MainActor.run {
                    servers = fetchedServers
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // VPN server credentials (embedded - users never see these)
    private static let vpnUser = "techvpn"
    private static let vpnPass = "TechVPN@2026!"
    
    private func selectServer(_ server: VPNServer) {
        configureAndDismiss(server: server)
    }
    
    private func configureAndDismiss(server: VPNServer) {
        let vpnUser = Self.vpnUser
        let vpnPass = Self.vpnPass
        vpnManager.selectedServer = server
        
        Task {
            do {
                let config = try await APIService.shared.fetchServerConfig(serverId: server.id)
                
                await MainActor.run {
                    vpnManager.configureVPN(
                        server: server,
                        config: config,
                        username: vpnUser,
                        password: vpnPass
                    )
                }
            } catch {
                print("Config fetch failed: \(error.localizedDescription)")
                // Configure with server IP directly as fallback
                await MainActor.run {
                    let fallbackConfig = VPNServerConfig(
                        serverAddress: server.ipAddress,
                        remoteIdentifier: server.ipAddress,
                        certificate: nil,
                        presharedKey: nil
                    )
                    vpnManager.configureVPN(
                        server: server,
                        config: fallbackConfig,
                        username: vpnUser,
                        password: vpnPass
                    )
                }
            }
        }
        
        dismiss()
    }
}

// MARK: - Server Row
struct ServerRowView: View {
    let server: VPNServer
    let isSelected: Bool
    let onTap: () -> Void
    
    private var loadColor: Color {
        if server.load < 50 { return AppTheme.Colors.success }
        else if server.load < 70 { return AppTheme.Colors.warning }
        else { return AppTheme.Colors.error }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Flag
                Circle()
                    .fill(AppTheme.Colors.surfaceContainerHighest)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(server.flagEmoji)
                            .font(.system(size: 16))
                    )
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.outlineVariant.opacity(0.2), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                        .foregroundColor(AppTheme.Colors.onSurface)
                    
                    Text(serverCity)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                }
                
                Spacer()
                
                // Load
                Text("\(server.load)%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(loadColor)
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.primaryContainer)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.2))
                }
            }
            .frame(height: 64)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(
                isSelected ? AppTheme.Colors.surfaceContainerHigh : Color.clear
            )
            .cornerRadius(AppTheme.Radius.lg)
            .overlay(
                HStack {
                    if isSelected {
                        Rectangle()
                            .fill(AppTheme.Colors.primaryContainer)
                            .frame(width: 4)
                            .cornerRadius(2)
                    }
                    Spacer()
                },
                alignment: .leading
            )
        }
    }
    
    private var serverCity: String {
        return server.country
    }
}

#Preview {
    ServerListView(vpnManager: VPNManager())
}
