//
//  SplashView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

struct SplashView: View {
    @State private var progress: CGFloat = 0
    @State private var statusText = "INITIALIZING_ENCRYPTION_LAYERS..."
    @State private var logoScale: CGFloat = 1.0
    @State private var logoGlow: CGFloat = 0.4
    @Binding var isFinished: Bool
    
    private let statusMessages = [
        "ESTABLISHING_SECURE_TUNNEL...",
        "OPTIMIZING_GLOBAL_NODES...",
        "VERIFYING_PROTOCOL_INTEGRITY...",
        "READY_FOR_CONNECTION"
    ]
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Vignette effect
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                VStack(spacing: 32) {
                    // Shield Logo
                    ZStack {
                        // Glow behind
                        Circle()
                            .fill(AppTheme.Colors.primaryContainer.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .blur(radius: 40)
                        
                        // Rotated border container
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppTheme.Colors.primaryContainer, lineWidth: 4)
                            .frame(width: 128, height: 128)
                            .rotationEffect(.degrees(45))
                            .overlay(
                                ZStack {
                                    Image(systemName: "shield")
                                        .font(.system(size: 60, weight: .ultraLight))
                                        .foregroundColor(AppTheme.Colors.primaryContainer)
                                    
                                    Text("T")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(AppTheme.Colors.primaryContainer)
                                }
                            )
                    }
                    .scaleEffect(logoScale)
                    .shadow(color: AppTheme.Colors.primaryContainer.opacity(logoGlow), radius: 15)
                    
                    // Identity
                    VStack(spacing: 8) {
                        Text("TECH VPN")
                            .font(.system(size: 36, weight: .heavy))
                            .tracking(6)
                            .foregroundColor(Color(hex: "#F2F2F2"))
                        
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(AppTheme.Colors.primaryContainer.opacity(0.3))
                                .frame(width: 32, height: 1)
                            
                            Text("SECURE. PRIVATE. FAST.")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(4)
                                .foregroundColor(AppTheme.Colors.primaryContainer)
                            
                            Rectangle()
                                .fill(AppTheme.Colors.primaryContainer.opacity(0.3))
                                .frame(width: 32, height: 1)
                        }
                    }
                }
                
                Spacer()
                
                // Loading bar
                VStack(spacing: 16) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(hex: "#161616"))
                                .frame(height: 2)
                            
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppTheme.Colors.primaryContainer)
                                .frame(width: geometry.size.width * progress, height: 2)
                                .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.8), radius: 4)
                        }
                    }
                    .frame(width: 192, height: 2)
                    
                    Text(statusText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.outline.opacity(0.5))
                        .tracking(2)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            logoScale = 1.02
            logoGlow = 0.7
        }
        
        // Progress animation
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            withAnimation(.easeOut(duration: 0.3)) {
                progress += CGFloat.random(in: 0.08...0.15)
                
                if progress > 0.25 && progress <= 0.55 {
                    statusText = statusMessages[1]
                } else if progress > 0.55 && progress <= 0.85 {
                    statusText = statusMessages[2]
                } else if progress > 0.85 {
                    statusText = statusMessages[3]
                }
                
                if progress >= 1.0 {
                    progress = 1.0
                    timer.invalidate()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isFinished = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
