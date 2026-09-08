//
//  ContentView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var vpnManager = VPNManager()
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var isGuestMode = false
    
    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    if !authService.isAuthenticated {
                        isGuestMode = true
                    }
                }
            } else {
                MainTabView(vpnManager: vpnManager, authService: authService, isGuestMode: $isGuestMode)
                    .onAppear {
                        if !authService.isAuthenticated {
                            isGuestMode = true
                        }
                        vpnManager.autoConnectIfNeeded()
                    }
                    .task {
                        await SubscriptionManager.shared.checkSubscriptionStatus()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
    }
}

#Preview {
    ContentView()
}
