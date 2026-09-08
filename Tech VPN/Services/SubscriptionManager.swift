//
//  SubscriptionManager.swift
//  Tech VPN
//
//  Created by Xylo on 09/09/26.
//

import Foundation
import Combine
import RevenueCat

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Constants
    static let apiKey = "appl_SnHWpPwEUJDrVKtZPjcNmhzNnIU"
    static let entitlementID = "pro_access"
    static let offeringID = "default_offering"
    
    struct ProductIDs {
        static let weekly = "com.techvpnpro.weekly"
        static let yearly = "com.techvpnpro.yearly"
        static let lifetime = "com.techvpnpro.lifetime"
    }
    
    // MARK: - Published Properties
    @Published var isProUser = false
    @Published var currentOffering: Offering?
    @Published var weeklyPackage: Package?
    @Published var yearlyPackage: Package?
    @Published var lifetimePackage: Package?
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private init() {}
    
    // MARK: - Configure
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
    }
    
    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            if let offering = offerings.offering(identifier: Self.offeringID) ?? offerings.current {
                self.currentOffering = offering
                
                for package in offering.availablePackages {
                    switch package.storeProduct.productIdentifier {
                    case ProductIDs.weekly:
                        self.weeklyPackage = package
                    case ProductIDs.yearly:
                        self.yearlyPackage = package
                    case ProductIDs.lifetime:
                        self.lifetimePackage = package
                    default:
                        break
                    }
                }
            }
        } catch {
            self.errorMessage = "Failed to load plans. Please try again."
            self.showError = true
        }
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.isProUser = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            // Silently fail — user stays on free tier
        }
    }
    
    // MARK: - Purchase
    func purchase(package: Package) async -> Bool {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPurchasing = false
            
            if !result.userCancelled {
                self.isProUser = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
                return self.isProUser
            }
            return false
        } catch {
            isPurchasing = false
            self.errorMessage = "Purchase failed. Please try again."
            self.showError = true
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPurchasing = false
            self.isProUser = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            
            if !self.isProUser {
                self.errorMessage = "No active subscription found."
                self.showError = true
            }
            return self.isProUser
        } catch {
            isPurchasing = false
            self.errorMessage = "Restore failed. Please try again."
            self.showError = true
            return false
        }
    }
}
