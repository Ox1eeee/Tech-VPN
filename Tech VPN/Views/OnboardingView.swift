//
//  OnboardingView.swift
//  Tech VPN
//
//  Created by Xylo on 11/08/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    var onComplete: () -> Void

    private let totalPages = 4

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button row
                HStack {
                    Spacer()
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(2)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.trailing, AppTheme.Spacing.safeMargin)
                    .padding(.top, AppTheme.Spacing.sm)
                }

                // TabView with pages
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    EncryptionPage()
                        .tag(1)
                    ServersPage()
                        .tag(2)
                    ConnectGoPage()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicators
                PageIndicators(currentPage: currentPage, totalPages: totalPages)
                    .padding(.bottom, AppTheme.Spacing.lg)

                // Action button
                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(2)
                        .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.Colors.primaryContainer)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.3), radius: 20)
                }
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onComplete()
    }
}

// MARK: - Page Indicators
private struct PageIndicators: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                if index == currentPage {
                    Capsule()
                        .fill(AppTheme.Colors.primaryContainer)
                        .frame(width: 24, height: 8)
                        .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.5), radius: 6)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(AppTheme.Colors.secondary.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}

// MARK: - Page 1: Welcome
private struct WelcomePage: View {
    @State private var floatOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryContainer.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)

                // Shield illustration
                WelcomeShieldAnimation()
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .offset(y: floatOffset)
            }
            .frame(maxWidth: 320)
            .padding(.bottom, AppTheme.Spacing.lg)

            // Typography
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("TECH VPN")
                    .font(.system(size: 37, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#E3E2E2"))

                Text("Your digital bodyguard.")
                    .font(.system(size: 21))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.5))
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floatOffset = -8
                scale = 1.05
            }
        }
    }
}

// MARK: - Welcome Shield Animation (SVG converted)
private struct WelcomeShieldAnimation: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2

            // Main shield shape
            let shieldPath = Path { path in
                path.move(to: CGPoint(x: cx, y: cy - 70))
                path.addCurve(
                    to: CGPoint(x: cx + 65, y: cy - 10),
                    control1: CGPoint(x: cx + 20, y: cy - 70),
                    control2: CGPoint(x: cx + 65, y: cy - 60)
                )
                path.addCurve(
                    to: CGPoint(x: cx + 65, y: cy + 40),
                    control1: CGPoint(x: cx + 65, y: cy + 20),
                    control2: CGPoint(x: cx + 50, y: cy + 35)
                )
                path.addCurve(
                    to: CGPoint(x: cx, y: cy + 85),
                    control1: CGPoint(x: cx + 40, y: cy + 75),
                    control2: CGPoint(x: cx + 20, y: cy + 85)
                )
                path.addCurve(
                    to: CGPoint(x: cx - 65, y: cy + 40),
                    control1: CGPoint(x: cx - 20, y: cy + 85),
                    control2: CGPoint(x: cx - 40, y: cy + 75)
                )
                path.addCurve(
                    to: CGPoint(x: cx - 65, y: cy - 10),
                    control1: CGPoint(x: cx - 50, y: cy + 35),
                    control2: CGPoint(x: cx - 65, y: cy + 20)
                )
                path.addCurve(
                    to: CGPoint(x: cx, y: cy - 70),
                    control1: CGPoint(x: cx - 65, y: cy - 60),
                    control2: CGPoint(x: cx - 20, y: cy - 70)
                )
            }

            context.fill(shieldPath, with: .color(Color(hex: "#E2231A")))

            // Left half overlay (lighter)
            let leftHalf = Path { path in
                path.move(to: CGPoint(x: cx, y: cy - 70))
                path.addCurve(
                    to: CGPoint(x: cx - 65, y: cy - 10),
                    control1: CGPoint(x: cx - 20, y: cy - 70),
                    control2: CGPoint(x: cx - 65, y: cy - 60)
                )
                path.addCurve(
                    to: CGPoint(x: cx - 65, y: cy + 40),
                    control1: CGPoint(x: cx - 65, y: cy + 20),
                    control2: CGPoint(x: cx - 50, y: cy + 35)
                )
                path.addCurve(
                    to: CGPoint(x: cx, y: cy + 85),
                    control1: CGPoint(x: cx - 40, y: cy + 75),
                    control2: CGPoint(x: cx - 20, y: cy + 85)
                )
                path.addLine(to: CGPoint(x: cx, y: cy - 70))
            }

            context.fill(leftHalf, with: .color(Color(hex: "#FF5F52").opacity(0.8)))
        }
        .frame(width: 200, height: 200)
    }
}

// MARK: - Page 2: Encryption
private struct EncryptionPage: View {
    @State private var rotateDashed: Double = 0
    @State private var rotateDots: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryContainer.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)

                EncryptionAnimation()
                    .frame(width: 200, height: 200)
            }
            .frame(maxWidth: 320)
            .padding(.bottom, AppTheme.Spacing.lg)

            // Typography
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Military-Grade\nEncryption")
                    .font(.system(size: 37, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#E3E2E2"))
                    .multilineTextAlignment(.center)

                Text("AES-256 encryption on every connection. Your data stays yours.")
                    .font(.system(size: 21))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)

            Spacer()
        }
    }
}

// MARK: - Encryption Animation (SVG converted)
private struct EncryptionAnimation: View {
    @State private var dashedRotation: Double = 0
    @State private var dotsRotation: Double = 0

    var body: some View {
        ZStack {
            // Dashed circle (rotating)
            Circle()
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [8, 8]
                    )
                )
                .foregroundColor(AppTheme.Colors.primaryContainer)
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(dashedRotation))

            // Lock body
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.primaryContainer)
                .frame(width: 50, height: 50)

            // Lock shackle
            ArcShape()
                .stroke(AppTheme.Colors.primaryContainer, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 30, height: 20)
                .offset(y: -22)

            // Orbiting dots
            ZStack {
                Circle().fill(AppTheme.Colors.primaryContainer.opacity(0.4)).frame(width: 8, height: 8).offset(y: -80)
                Circle().fill(AppTheme.Colors.primaryContainer.opacity(0.4)).frame(width: 8, height: 8).offset(x: 80)
                Circle().fill(AppTheme.Colors.primaryContainer.opacity(0.4)).frame(width: 8, height: 8).offset(y: 80)
                Circle().fill(AppTheme.Colors.primaryContainer.opacity(0.4)).frame(width: 8, height: 8).offset(x: -80)
            }
            .rotationEffect(.degrees(dotsRotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                dashedRotation = 360
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                dotsRotation = 360
            }
        }
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

// MARK: - Page 3: Servers
private struct ServersPage: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryContainer.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)

                ServersAnimation()
                    .frame(width: 200, height: 200)
            }
            .frame(maxWidth: 320)
            .padding(.bottom, AppTheme.Spacing.lg)

            // Typography
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Servers Worldwide")
                    .font(.system(size: 37, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#E3E2E2"))
                    .multilineTextAlignment(.center)

                Text("Connect to optimized locations across the globe. Zero lag, maximum speed.")
                    .font(.system(size: 21))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)

            Spacer()
        }
    }
}

// MARK: - Servers Animation (SVG converted)
private struct ServersAnimation: View {
    @State private var globeRotation: Double = 0
    @State private var bolt1Opacity: Double = 0.3
    @State private var bolt2Opacity: Double = 0.3
    @State private var bolt3Opacity: Double = 0.3

    var body: some View {
        ZStack {
            // Globe with meridians (rotating)
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.primaryContainer, lineWidth: 2)
                    .frame(width: 140, height: 140)

                // Meridian 1
                MeridianShape()
                    .stroke(AppTheme.Colors.primaryContainer, lineWidth: 1)
                    .frame(width: 140, height: 140)

                // Meridian 2
                MeridianShape2()
                    .stroke(AppTheme.Colors.primaryContainer, lineWidth: 1)
                    .frame(width: 140, height: 140)
            }
            .rotationEffect(.degrees(globeRotation))

            // Lightning bolts (pulsing)
            BoltShape()
                .stroke(AppTheme.Colors.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 35)
                .offset(x: -40, y: -60)
                .opacity(bolt1Opacity)

            BoltShape()
                .stroke(AppTheme.Colors.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 35)
                .offset(x: 40, y: -60)
                .opacity(bolt2Opacity)

            BoltShape()
                .stroke(AppTheme.Colors.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 35)
                .offset(x: 0, y: 40)
                .opacity(bolt3Opacity)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                globeRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bolt1Opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.5)) {
                bolt2Opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1.0)) {
                bolt3Opacity = 1.0
            }
        }
    }
}

private struct MeridianShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = rect.width / 2
        path.move(to: CGPoint(x: cx - r, y: cy))
        path.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx, y: cy - r))
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx, y: cy + r))
        return path
    }
}

private struct MeridianShape2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = rect.width / 2
        path.move(to: CGPoint(x: cx, y: cy - r))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r, y: cy))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r, y: cy))
        return path
    }
}

private struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Lightning bolt zigzag
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

// MARK: - Page 4: Connect & Go
private struct ConnectGoPage: View {
    @State private var innerScale: CGFloat = 1.0
    @State private var innerOpacity: Double = 1.0
    @State private var outerScale: CGFloat = 1.0
    @State private var outerOpacity: Double = 0.5

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animation
            ZStack {
                // Ripple outer circle
                Circle()
                    .stroke(AppTheme.Colors.primaryContainer, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(outerScale)
                    .opacity(outerOpacity)

                // Inner pulsing circle
                Circle()
                    .stroke(AppTheme.Colors.primaryContainer, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(innerScale)
                    .opacity(innerOpacity)

                // Power icon
                PowerSymbolShape()
                    .stroke(AppTheme.Colors.primaryContainer, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
            }
            .frame(width: 200, height: 200)
            .padding(.bottom, AppTheme.Spacing.lg)

            // Typography
            VStack(spacing: AppTheme.Spacing.base) {
                Text("One Tap to Connect")
                    .font(.system(size: 37, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#E3E2E2"))
                    .multilineTextAlignment(.center)

                Text("Pick a server, tap connect, and browse securely. It's that simple.")
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                innerScale = 1.08
                innerOpacity = 0.5
            }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                outerScale = 1.3
                outerOpacity = 0.0
            }
        }
    }
}

private struct PowerSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Vertical line
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.7))
        // Arc (open at top)
        let radius = rect.width * 0.4
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.5),
            radius: radius,
            startAngle: .degrees(135),
            endAngle: .degrees(45),
            clockwise: true
        )
        return path
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
