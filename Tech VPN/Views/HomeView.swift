//
//  HomeView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var vpnManager: VPNManager
    @ObservedObject var authService: AuthService
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    var onProfileTap: () -> Void = {}
    
    @State private var showServerList = false
    @State private var connectionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var elapsedTime: String = "00:00:00"
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.surfaceContainerLowest
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                topBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Server Selector
                        serverSelector
                            .padding(.top, AppTheme.Spacing.lg)
                        
                        // Central Connect Interface
                        connectInterface
                            .padding(.vertical, AppTheme.Spacing.xl)
                        
                        // Speed Metrics
                        speedMetrics
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showServerList) {
            ServerListView(vpnManager: vpnManager)
        }
        .onReceive(connectionTimer) { _ in
            updateTimer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                // Profile avatar (clickable)
                Button(action: onProfileTap) {
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
                
                Text("TECH VPN")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            Spacer()
            
            Button(action: onProfileTap) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
        .frame(height: 64)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Server Selector
    private var serverSelector: some View {
        Button(action: { showServerList = true }) {
            HStack(spacing: 12) {
                if let server = vpnManager.selectedServer {
                    Text(server.flagEmoji)
                        .font(.system(size: 18))
                    
                    Text("\(server.name.uppercased())")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundColor(AppTheme.Colors.onSurface)
                } else {
                    Text("🌐")
                        .font(.system(size: 18))
                    
                    Text("SELECT SERVER")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundColor(AppTheme.Colors.onSurface)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(AppTheme.Colors.surfaceContainerHigh)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Connect Interface
    private var connectInterface: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Connect Button with pulse
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(AppTheme.Colors.primary.opacity(0.1), lineWidth: 2)
                    .frame(width: 256, height: 256)
                    .scaleEffect(pulseScale)
                    .opacity(vpnManager.isConnected ? 0.6 : 0.3)
                
                // Main button
                Button(action: {
                    vpnManager.toggleConnection()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                vpnManager.isConnected
                                    ? AppTheme.Colors.primaryContainer
                                    : AppTheme.Colors.surfaceContainerLow
                            )
                            .frame(width: 208, height: 208)
                            .overlay(
                                Circle()
                                    .stroke(
                                        vpnManager.isConnected
                                            ? AppTheme.Colors.primaryContainer
                                            : AppTheme.Colors.primaryContainer.opacity(0.3),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(
                                color: vpnManager.isConnected
                                    ? AppTheme.Colors.primaryContainer.opacity(0.6)
                                    : AppTheme.Colors.primaryContainer.opacity(0.1),
                                radius: vpnManager.isConnected ? 40 : 10
                            )
                        
                        // Shield icon
                        Image(systemName: vpnManager.isConnected ? "shield.fill" : "shield")
                            .font(.system(size: 80, weight: .thin))
                            .foregroundColor(
                                vpnManager.isConnected
                                    ? AppTheme.Colors.onPrimaryContainer
                                    : AppTheme.Colors.primaryContainer
                            )
                    }
                }
                .disabled(vpnManager.selectedServer == nil || vpnManager.status == .connecting || vpnManager.status == .disconnecting)
                .opacity(vpnManager.selectedServer == nil ? 0.5 : 1.0)
            }
            
            // Status label
            VStack(spacing: 8) {
                if vpnManager.isConnected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 8, height: 8)
                        
                        Text("PROTECTED")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundColor(AppTheme.Colors.onSurface)
                    }
                    
                    Text(elapsedTime)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.onSurface)
                    
                    Text("IP: \(vpnManager.publicIP.isEmpty ? "..." : vpnManager.publicIP)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.outlineVariant.opacity(0.6))
                } else if vpnManager.status == .connecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppTheme.Colors.primaryContainer)
                            .scaleEffect(0.8)
                        
                        Text("CONNECTING...")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                } else {
                    Text("TAP TO CONNECT")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundColor(AppTheme.Colors.secondary)
                    
                    Text("IP: \(vpnManager.publicIP.isEmpty ? "..." : vpnManager.publicIP)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.outlineVariant.opacity(0.6))
                }
            }
        }
    }
    
    // MARK: - Speed Metrics
    private var speedMetrics: some View {
        HStack(spacing: AppTheme.Spacing.gutter) {
            // Download
            MetricCard(
                icon: "arrow.down",
                label: "DOWN",
                value: String(format: "%.1f", networkMonitor.downloadSpeed),
                unit: "MBPS"
            )
            
            // Upload
            MetricCard(
                icon: "arrow.up",
                label: "UP",
                value: String(format: "%.1f", networkMonitor.uploadSpeed),
                unit: "MBPS"
            )
        }
    }
    
    // MARK: - Timer
    private func updateTimer() {
        guard let startDate = vpnManager.connectedDate else {
            elapsedTime = "00:00:00"
            return
        }
        let interval = Date().timeIntervalSince(startDate)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primaryContainer)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.8))
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.onSurface)
                
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.outlineVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.surfaceContainer)
        .cornerRadius(AppTheme.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(AppTheme.Colors.outlineVariant.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView(vpnManager: VPNManager(), authService: AuthService.shared)
}
