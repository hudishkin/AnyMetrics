//
//  ReviewHandler.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 29.06.2022.
//

import Foundation
import StoreKit
import SwiftUI
import AnyMetricsShared

enum ReviewHandler {

    enum Trigger {
        case firstUserAdd
        case existingUserLaunch
        case periodic

        var analyticsValue: String {
            switch self {
            case .firstUserAdd: return "first_add"
            case .existingUserLaunch: return "existing_user"
            case .periodic: return "periodic"
            }
        }
    }

    private enum Constants {
        static let cooldown: TimeInterval = 21 * 24 * 60 * 60
        static let minLaunchesBetweenPrompts = 5
        static let maxStoreKitPerYear = 3
    }

    private static var didRecordLaunch = false

    static func recordAppLaunchIfNeeded() {
        guard !isPreview, !didRecordLaunch else { return }
        didRecordLaunch = true
        AppSettings.appLaunchCount += 1
    }

    static func hasUserAddedMetrics(_ metrics: Metrics) -> Bool {
        metrics.keys.contains { !StarterMetric.isStarter($0) }
    }

    static func shouldPrompt(_ trigger: Trigger, metrics: Metrics) -> Bool {
        guard !isPreview else { return false }
        guard !AppSettings.reviewPromptDisabled, !AppSettings.reviewCompleted else { return false }

        switch trigger {
        case .firstUserAdd:
            return !AppSettings.hasPromptedReview
        case .existingUserLaunch:
            return !AppSettings.hasPromptedReview && hasUserAddedMetrics(metrics)
        case .periodic:
            guard AppSettings.hasPromptedReview, hasUserAddedMetrics(metrics) else { return false }
            guard let lastPromptAt = AppSettings.lastReviewPromptAt else { return false }
            let enoughTime = Date().timeIntervalSince(lastPromptAt) >= Constants.cooldown
            let enoughLaunches = AppSettings.appLaunchCount - AppSettings.lastReviewPromptLaunchCount
                >= Constants.minLaunchesBetweenPrompts
            return enoughTime && enoughLaunches
        }
    }

    static func recordPromptShown() {
        AppSettings.hasPromptedReview = true
        AppSettings.lastReviewPromptAt = Date()
        AppSettings.lastReviewPromptLaunchCount = AppSettings.appLaunchCount
    }

    static func markCompleted() {
        guard !AppSettings.reviewCompleted else { return }
        AppSettings.reviewCompleted = true
        AnalyticsEvents.reviewCompleted()
    }

    static func markLater() {
        AnalyticsEvents.reviewLater()
    }

    static func markDeclined() {
        guard !AppSettings.reviewPromptDisabled else { return }
        AppSettings.reviewPromptDisabled = true
        AnalyticsEvents.reviewDeclined()
    }

    static func requestReview(countsTowardAnnualLimit: Bool = true) {
        if countsTowardAnnualLimit, !consumeStoreKitQuota() {
            return
        }
        presentStoreKit()
    }

#if DEBUG
    static func reset() {
        AppSettings.reviewPromptDisabled = false
        AppSettings.reviewCompleted = false
        AppSettings.hasPromptedReview = false
        AppSettings.lastReviewPromptAt = nil
        AppSettings.lastReviewPromptLaunchCount = 0
        AppSettings.reviewStoreKitCount = 0
        AppSettings.reviewStoreKitYear = 0
    }
#endif

    private static func consumeStoreKitQuota() -> Bool {
        let year = Calendar.current.component(.year, from: Date())
        if AppSettings.reviewStoreKitYear != year {
            AppSettings.reviewStoreKitYear = year
            AppSettings.reviewStoreKitCount = 0
        }
        guard AppSettings.reviewStoreKitCount < Constants.maxStoreKitPerYear else {
            return false
        }
        AppSettings.reviewStoreKitCount += 1
        return true
    }

    private static func presentStoreKit() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
