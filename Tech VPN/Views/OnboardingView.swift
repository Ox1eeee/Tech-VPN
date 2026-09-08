//
//  OnboardingView.swift
//  Tech VPN
//
//  Created by Xylo on 11/08/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "onboarding1",
            title: "TECH VPN",
            subtitle: "Your digital bodyguard."
        ),
        OnboardingPage(
            imageName: "onboarding2",
            title: "Military-Grade\nEncryption",
            subtitle: "AES-256 encryption on every connection. Your data stays yours."
        ),
        OnboardingPage(
            imageName: "onboarding3",
            title: "Servers Worldwide",
            subtitle: "Connect to optimized locations across the globe. Zero lag, maximum speed."
        ),
        OnboardingPage(
            imageName: "onboarding4",
            title: "One Tap to Connect",
            subtitle: "Pick a server, tap connect, and browse securely. It's that simple."
        ),
    ]

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages (no swipe)
                OnboardingPageView(page: pages[currentPage])
                    .id(currentPage)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicators
                PageIndicators(currentPage: currentPage, totalPages: pages.count)
                    .padding(.bottom, AppTheme.Spacing.lg)

                // Action button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
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

// MARK: - Data Model
private struct OnboardingPage {
    let imageName: String
    let title: String
    let subtitle: String
}

// MARK: - Page View
private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Image
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 280)
                .padding(.bottom, AppTheme.Spacing.lg)

            // Typography
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(page.title)
                    .font(.system(size: 37, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#E3E2E2"))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.horizontal, AppTheme.Spacing.safeMargin)

            Spacer()
        }
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

#Preview {
    OnboardingView(onComplete: {})
}
