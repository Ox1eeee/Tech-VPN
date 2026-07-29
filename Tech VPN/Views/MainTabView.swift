//
//  MainTabView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case servers = 1
    case stats = 2
    case settings = 3
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .servers: return "server.rack"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @ObservedObject var vpnManager: VPNManager
    @ObservedObject var authService: AuthService
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    HomeView(vpnManager: vpnManager, authService: authService)
                case .servers:
                    ServerListView(vpnManager: vpnManager)
                case .stats:
                    StatsView(vpnManager: vpnManager)
                case .settings:
                    SettingsView(authService: authService, vpnManager: vpnManager)
                }
            }
            
            // Bottom Navigation Bar
            bottomNavBar
        }
        .preferredColorScheme(.dark)
    }
    
    private var bottomNavBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.secondary)
                            .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                            .shadow(color: selectedTab == tab ? AppTheme.Colors.primaryContainer.opacity(0.4) : .clear, radius: 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .padding(.bottom, 10)
        .background(
            AppTheme.Colors.surfaceContainerLowest
                .overlay(
                    Rectangle()
                        .fill(AppTheme.Colors.outlineVariant.opacity(0.1))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}

#Preview {
    MainTabView(vpnManager: VPNManager(), authService: AuthService.shared)
}
