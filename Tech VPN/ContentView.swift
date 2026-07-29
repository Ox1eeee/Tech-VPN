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
    
    var body: some View {
        MainTabView(vpnManager: vpnManager, authService: authService)
    }
}

#Preview {
    ContentView()
}
