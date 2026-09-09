//
//  RatingManager.swift
//  Tech VPN
//

import StoreKit
import UIKit

/// Decides when to show the native App Store rating prompt.
/// Apple's SKStoreReviewController automatically suppresses the dialog if it
/// has already been shown 3 times in 365 days, so it is safe to call
/// requestReview() whenever a good moment arises.
final class RatingManager {
    static let shared = RatingManager()

    private let keyTotalConnections   = "rating_totalConnections"
    private let keyHasRatedAfterPurchase = "rating_hasRatedAfterPurchase"
    private let keyLastPromptDate     = "rating_lastPromptDate"
    private let keyConnectedMinutes   = "rating_connectedMinutesTotal"

    /// Our own minimum days between prompts (Apple caps at 3× per 365 days)
    private let minDaysBetweenPrompts: Double = 30

    private init() {}

    // MARK: - Trigger: successful VPN connection

    func didConnect() {
        let count = UserDefaults.standard.integer(forKey: keyTotalConnections) + 1
        UserDefaults.standard.set(count, forKey: keyTotalConnections)
        // Good moments: 3rd connect (habit forming), 10th (loyal user), 25th (power user)
        if count == 3 || count == 10 || count == 25 {
            requestReview()
        }
    }

    // MARK: - Trigger: 5 minutes connected (actively getting value)

    func didReachFiveMinutesConnected() {
        let total = UserDefaults.standard.integer(forKey: keyConnectedMinutes) + 5
        UserDefaults.standard.set(total, forKey: keyConnectedMinutes)
        // First 5-min session, then every accumulated hour
        if total == 5 || (total > 5 && total % 60 == 0) {
            requestReview()
        }
    }

    // MARK: - Trigger: successful purchase (peak satisfaction)

    func didPurchasePro() {
        guard !UserDefaults.standard.bool(forKey: keyHasRatedAfterPurchase) else { return }
        UserDefaults.standard.set(true, forKey: keyHasRatedAfterPurchase)
        // Small delay so the subscription sheet can dismiss first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.requestReview()
        }
    }

    // MARK: - Core

    private func requestReview() {
        if let last = UserDefaults.standard.object(forKey: keyLastPromptDate) as? Date {
            let daysSince = Date().timeIntervalSince(last) / 86400
            guard daysSince >= minDaysBetweenPrompts else { return }
        }
        UserDefaults.standard.set(Date(), forKey: keyLastPromptDate)

        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
