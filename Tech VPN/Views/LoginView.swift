//
//  LoginView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authService: AuthService
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showPassword = false
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(AppTheme.Colors.primaryContainer.opacity(0.05))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Spacer().frame(height: 40)
                        
                        // Logo Section
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "shield")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Colors.primaryContainer)
                            
                            Text("TECH VPN")
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-0.5)
                                .foregroundColor(AppTheme.Colors.onBackground)
                        }
                        
                        // Tab Toggle
                        HStack(spacing: 0) {
                            TabButton(title: "LOG IN", isActive: !isSignUp) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSignUp = false
                                    authService.errorMessage = nil
                                }
                            }
                            TabButton(title: "SIGN UP", isActive: isSignUp) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSignUp = true
                                    authService.errorMessage = nil
                                }
                            }
                        }
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1),
                            alignment: .bottom
                        )
                        
                        // Form Fields
                        VStack(spacing: AppTheme.Spacing.sm) {
                            if isSignUp {
                                AuthInputField(
                                    label: "EMAIL ADDRESS",
                                    placeholder: "name@example.com",
                                    text: $email,
                                    isSecure: false
                                )
                            }
                            
                            AuthInputField(
                                label: "USERNAME",
                                placeholder: "username",
                                text: $username,
                                isSecure: false
                            )
                            
                            AuthInputField(
                                label: "PASSWORD",
                                placeholder: "••••••••",
                                text: $password,
                                isSecure: !showPassword,
                                trailingIcon: showPassword ? "eye.slash" : "eye",
                                onTrailingTap: { showPassword.toggle() }
                            )
                            
                            if isSignUp {
                                AuthInputField(
                                    label: "CONFIRM PASSWORD",
                                    placeholder: "••••••••",
                                    text: $confirmPassword,
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Error message
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.error)
                                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        }
                        
                        // Primary Action Button
                        Button(action: performAction) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .tint(AppTheme.Colors.onPrimaryContainer)
                                } else {
                                    Text(isSignUp ? "SIGN UP" : "LOG IN")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.Colors.primaryContainer)
                            .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.3), radius: 20)
                        }
                        .disabled(authService.isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Forgot Password
                        if !isSignUp {
                            Button(action: {}) {
                                Text("Forgot Password?")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.secondary)
                            }
                        }
                        
                        // Divider
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                            Text("OR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.Colors.secondary)
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Apple Sign In
                        Button(action: {}) {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18))
                                Text("CONTINUE WITH APPLE")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .foregroundColor(AppTheme.Colors.onSurface)
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.Colors.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Footer
                        Text("By continuing, you agree to Tech VPN's Terms of Service and Privacy Policy.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                            .padding(.top, AppTheme.Spacing.lg)
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !username.isEmpty && !email.isEmpty && !password.isEmpty
                && password == confirmPassword && password.count >= 6
        }
        return !username.isEmpty && !password.isEmpty
    }
    
    private func performAction() {
        Task {
            if isSignUp {
                await authService.signup(email: email, username: username, password: password)
            } else {
                await authService.login(username: username, password: password)
            }
        }
    }
}

// MARK: - Tab Button
private struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(isActive ? AppTheme.Colors.onSurface : Color(hex: "#8A8A8A"))
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(isActive ? AppTheme.Colors.primaryContainer : Color.clear)
                    .frame(height: 2)
            }
        }
    }
}

// MARK: - Auth Input Field
struct AuthInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    var trailingIcon: String? = nil
    var onTrailingTap: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(AppTheme.Colors.secondary)
            
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(AppTheme.Colors.onSurface)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .foregroundColor(AppTheme.Colors.onSurface)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                }
                
                if let icon = trailingIcon {
                    Button(action: { onTrailingTap?() }) {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
            }
            .padding(AppTheme.Spacing.sm)
            .background(Color(hex: "#161616"))
            .cornerRadius(AppTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .stroke(
                        isFocused ? AppTheme.Colors.primaryContainer : Color(hex: "#333333"),
                        lineWidth: 1
                    )
            )
        }
    }
}

#Preview {
    LoginView(authService: AuthService.shared)
}
