//
//  AppTheme.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

// MARK: - Kinetic Red Design System
struct AppTheme {
    // MARK: - Colors
    struct Colors {
        // Primary
        static let primary = Color(hex: "#ffb4a9")
        static let primaryContainer = Color(hex: "#e2231a")
        static let onPrimary = Color(hex: "#690001")
        static let onPrimaryContainer = Color(hex: "#fffaff")
        
        // Surface
        static let surface = Color(hex: "#121414")
        static let surfaceDim = Color(hex: "#121414")
        static let surfaceBright = Color(hex: "#383939")
        static let surfaceContainerLowest = Color(hex: "#0d0e0f")
        static let surfaceContainerLow = Color(hex: "#1b1c1c")
        static let surfaceContainer = Color(hex: "#1f2020")
        static let surfaceContainerHigh = Color(hex: "#292a2a")
        static let surfaceContainerHighest = Color(hex: "#343535")
        
        // On-Surface
        static let onSurface = Color(hex: "#e3e2e2")
        static let onSurfaceVariant = Color(hex: "#e7bdb7")
        static let onBackground = Color(hex: "#e3e2e2")
        
        // Secondary
        static let secondary = Color(hex: "#c8c6c5")
        static let secondaryContainer = Color(hex: "#474746")
        static let onSecondary = Color(hex: "#313030")
        
        // Outline
        static let outline = Color(hex: "#ae8882")
        static let outlineVariant = Color(hex: "#5d3f3b")
        
        // Error
        static let error = Color(hex: "#ffb4ab")
        static let errorContainer = Color(hex: "#93000a")
        
        // Background
        static let background = Color(hex: "#0A0A0A")
        
        // Inverse
        static let inversePrimary = Color(hex: "#c00005")
        
        // Functional
        static let success = Color(hex: "#4ADE80")
        static let warning = Color(hex: "#FACC15")
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let base: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 16
        static let md: CGFloat = 24
        static let lg: CGFloat = 32
        static let xl: CGFloat = 48
        static let safeMargin: CGFloat = 20
        static let gutter: CGFloat = 16
    }
    
    // MARK: - Corner Radius
    struct Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
