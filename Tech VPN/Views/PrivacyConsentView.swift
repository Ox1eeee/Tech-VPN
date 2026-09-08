//
//  PrivacyConsentView.swift
//  Tech VPN
//
//  Created by Xylo on 09/09/26.
//

import SwiftUI

struct PrivacyConsentView: View {
    var onAccept: () -> Void
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        // Exit the app — user cannot proceed without accepting
                        exit(0)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.Colors.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                .padding(.top, AppTheme.Spacing.sm)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        // Title
                        Text("Your Privacy, Your Control")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                            .padding(.top, AppTheme.Spacing.lg)
                        
                        // Intro
                        Text("Hey there! Thanks for choosing Tech VPN Pro \u{2014} we've got your back when it comes to online privacy.")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .lineSpacing(4)
                        
                        Text("We only collect the bare minimum data needed to keep your connection smooth and secure. Here's a quick breakdown:")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .lineSpacing(4)
                        
                        // Email section
                        Group {
                            Text("*Email (Optional)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.onSurface)
                            + Text(" \u{2013} Helps with login, password recovery, and service updates. But no worries, you can still use most of our features without signing up.")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        .lineSpacing(4)
                        
                        // Anonymous data section
                        Group {
                            Text("*Anonymous Usage Data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.onSurface)
                            + Text(" \u{2013} Stuff like your device type, OS version, and error reports. This helps us fix bugs and make sure your VPN runs like a dream.")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        .lineSpacing(4)
                        
                        // No-logs promise
                        Text("That's it. No tracking your browsing history, no selling your data. We stick to a strict no-logs policy and follow privacy laws to the letter. Your data stays yours.")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.primaryContainer)
                            .lineSpacing(4)
                        
                        // Links
                        HStack(spacing: 4) {
                            Text("Want the full details? Check out our")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.secondary)
                            
                        }
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/terms-of-service/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Terms of Service")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primaryContainer)
                            }
                            
                            Text("and")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.secondary)
                            
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/privacy-policy-2/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primaryContainer)
                            }
                        }
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, AppTheme.Spacing.safeMargin)
                }
                
                // Agree button
                Button(action: onAccept) {
                    Text("Agree")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(1)
                        .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primaryContainer)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.4), radius: 20)
                }
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PrivacyConsentView(onAccept: {})
}
