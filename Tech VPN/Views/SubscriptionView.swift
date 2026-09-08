//
//  SubscriptionView.swift
//  Tech VPN
//
//  Created by Xylo on 09/09/26.
//

import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: PlanType = .yearly
    
    enum PlanType {
        case weekly, yearly, lifetime
    }
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(AppTheme.Colors.primaryContainer.opacity(0.06))
                .frame(width: 350, height: 350)
                .blur(radius: 100)
                .offset(y: -200)
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.safeMargin)
                .padding(.top, 8)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Shield icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.primaryContainer.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "shield.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.Colors.primaryContainer)
                        }
                        .padding(.top, AppTheme.Spacing.sm)
                        
                        // Title
                        Text("Premium Features")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                        
                        // Subtitle
                        Text("Get unlimited access to all premium features")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        // Feature list
                        VStack(alignment: .leading, spacing: 14) {
                            featureRow(icon: "shield.fill", text: "Unlock premium servers", color: AppTheme.Colors.primaryContainer)
                            featureRow(icon: "bolt.fill", text: "Ad-Free & Fast servers", color: AppTheme.Colors.primaryContainer)
                            featureRow(icon: "globe", text: "Unlimited bandwidth", color: AppTheme.Colors.primaryContainer)
                            featureRow(icon: "iphone.gen3", text: "Connect multiple devices", color: AppTheme.Colors.primaryContainer)
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin + 8)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        
                        // Plan cards
                        VStack(spacing: 12) {
                            lifetimePlanCard
                            yearlyPlanCard
                            weeklyPlanCard
                        }
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        .padding(.top, AppTheme.Spacing.xs)
                        
                        // Continue button
                        Button(action: handlePurchase) {
                            HStack {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(AppTheme.Colors.onPrimaryContainer)
                                } else {
                                    Text("Continue")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.primaryContainer)
                            .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.4), radius: 20)
                        }
                        .disabled(subscriptionManager.isPurchasing)
                        .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        .padding(.top, AppTheme.Spacing.xs)
                        
                        // Disclaimer text
                        Text(disclaimerText)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.secondary.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.safeMargin + 4)
                            .padding(.top, 4)
                        
                        // Restore & Legal links
                        HStack(spacing: 24) {
                            Button(action: handleRestore) {
                                Text("Restore")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                            }
                            
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/terms-of-service/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Terms of Use")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                            }
                            
                            Text("&")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
                            
                            Button(action: {
                                if let url = URL(string: "https://techvpnpro.com/privacy-policy-2/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.7))
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await subscriptionManager.fetchOfferings()
        }
        .alert("Error", isPresented: $subscriptionManager.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscriptionManager.errorMessage ?? "An error occurred.")
        }
    }
    
    // MARK: - Feature Row
    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.onSurface)
        }
    }
    
    // MARK: - Lifetime Plan Card
    private var lifetimePlanCard: some View {
        Button(action: { selectedPlan = .lifetime }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Lifetime Plan")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                        
                        Text("Best Value")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.primaryContainer)
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4) {
                        Text("Pay once, use forever")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        if let pkg = subscriptionManager.lifetimePackage {
                            Text(pkg.storeProduct.localizedPriceString)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.secondary)
                            Text("one-time")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                    }
                }
                
                Spacer()
                
                planRadio(isSelected: selectedPlan == .lifetime)
            }
            .padding(16)
            .background(AppTheme.Colors.surfaceContainer)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedPlan == .lifetime
                            ? AppTheme.Colors.primaryContainer
                            : AppTheme.Colors.outlineVariant.opacity(0.2),
                        lineWidth: selectedPlan == .lifetime ? 2 : 1
                    )
            )
        }
    }
    
    // MARK: - Yearly Helpers
    private var yearlySavingsPercent: Int? {
        guard let weeklyPkg = subscriptionManager.weeklyPackage,
              let yearlyPkg = subscriptionManager.yearlyPackage else { return nil }
        let weeklyPrice = weeklyPkg.storeProduct.price as Decimal
        let yearlyPrice = yearlyPkg.storeProduct.price as Decimal
        let fullYearWeekly = weeklyPrice * 52
        guard fullYearWeekly > 0 else { return nil }
        return Int(((Double(truncating: (fullYearWeekly - yearlyPrice) as NSDecimalNumber) / Double(truncating: fullYearWeekly as NSDecimalNumber)) * 100).rounded())
    }
    
    private var yearlyWeeklyEquivalent: String? {
        guard let pkg = subscriptionManager.yearlyPackage else { return nil }
        let yearlyPrice = pkg.storeProduct.price as Decimal
        let weeklyEquiv = yearlyPrice / 52
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = pkg.storeProduct.priceFormatter?.locale ?? .current
        return formatter.string(from: weeklyEquiv as NSDecimalNumber)
    }
    
    // MARK: - Yearly Plan Card
    private var yearlyPlanCard: some View {
        Button(action: { selectedPlan = .yearly }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Yearly Plan")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.Colors.onSurface)
                        
                        if let savings = yearlySavingsPercent {
                            Text("Save \(savings)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.Colors.onPrimaryContainer)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.Colors.primaryContainer)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("3 days free, then")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        if let pkg = subscriptionManager.yearlyPackage {
                            Text("\(pkg.storeProduct.localizedPriceString)/yr")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        
                        if let weeklyStr = yearlyWeeklyEquivalent {
                            Text("(\(weeklyStr)/wk)")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                    }
                }
                
                Spacer()
                
                planRadio(isSelected: selectedPlan == .yearly)
            }
            .padding(16)
            .background(
                selectedPlan == .yearly
                    ? AppTheme.Colors.primaryContainer.opacity(0.08)
                    : AppTheme.Colors.surfaceContainer
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedPlan == .yearly
                            ? AppTheme.Colors.primaryContainer
                            : AppTheme.Colors.outlineVariant.opacity(0.2),
                        lineWidth: selectedPlan == .yearly ? 2 : 1
                    )
            )
        }
    }
    
    // MARK: - Weekly Plan Card
    private var weeklyPlanCard: some View {
        Button(action: { selectedPlan = .weekly }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Plan")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.Colors.onSurface)
                    
                    HStack(spacing: 4) {
                        if let pkg = subscriptionManager.weeklyPackage {
                            Text("\(pkg.storeProduct.localizedPriceString)/wk.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        Text("Auto-renew")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                }
                
                Spacer()
                
                planRadio(isSelected: selectedPlan == .weekly)
            }
            .padding(16)
            .background(AppTheme.Colors.surfaceContainer)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedPlan == .weekly
                            ? AppTheme.Colors.primaryContainer
                            : AppTheme.Colors.outlineVariant.opacity(0.2),
                        lineWidth: selectedPlan == .weekly ? 2 : 1
                    )
            )
        }
    }
    
    // MARK: - Radio Button
    private func planRadio(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? AppTheme.Colors.primaryContainer : AppTheme.Colors.secondary.opacity(0.4),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)
            
            if isSelected {
                Circle()
                    .fill(AppTheme.Colors.primaryContainer)
                    .frame(width: 16, height: 16)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.onPrimaryContainer)
            }
        }
    }
    
    // MARK: - Disclaimer
    private var disclaimerText: String {
        "Yearly plan: Start with a 3-day free trial, then auto-renew. Cancel anytime before trial ends. Weekly plan: Auto-renew subscription. Lifetime plan: One-time purchase, no recurring charges. You can manage your subscription anytime in your App Store account settings."
    }
    
    // MARK: - Actions
    private func handlePurchase() {
        Task {
            var package: Package?
            switch selectedPlan {
            case .weekly:
                package = subscriptionManager.weeklyPackage
            case .yearly:
                package = subscriptionManager.yearlyPackage
            case .lifetime:
                package = subscriptionManager.lifetimePackage
            }
            
            guard let pkg = package else {
                subscriptionManager.errorMessage = "Plan not available. Please try again."
                subscriptionManager.showError = true
                return
            }
            
            let success = await subscriptionManager.purchase(package: pkg)
            if success {
                dismiss()
            }
        }
    }
    
    private func handleRestore() {
        Task {
            let success = await subscriptionManager.restorePurchases()
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    SubscriptionView()
}
