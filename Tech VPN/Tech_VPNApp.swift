//
//  Tech_VPNApp.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI
import Firebase

@main
struct Tech_VPNApp: App {
    init() {
        FirebaseApp.configure()
        SubscriptionManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
