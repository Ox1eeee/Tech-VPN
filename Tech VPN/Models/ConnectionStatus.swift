//
//  ConnectionStatus.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import SwiftUI

enum VPNConnectionStatus: String {
    case connected = "Connected"
    case connecting = "Connecting..."
    case disconnecting = "Disconnecting..."
    case disconnected = "Disconnected"
    case invalid = "Invalid"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .connecting, .disconnecting:
            return .orange
        case .disconnected:
            return .red
        case .invalid, .unknown:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .connected:
            return "lock.shield.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "lock.open.fill"
        case .invalid, .unknown:
            return "exclamationmark.triangle.fill"
        }
    }
}
