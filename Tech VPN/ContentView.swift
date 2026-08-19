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
                }
            } else if authService.isAuthenticated || isGuestMode {
                MainTabView(vpnManager: vpnManager, authService: authService, isGuestMode: $isGuestMode)
            } else {
                LoginView(authService: authService) {
                    isGuestMode = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.3), value: isGuestMode)
    }
}

#Preview {
    ContentView()
}
