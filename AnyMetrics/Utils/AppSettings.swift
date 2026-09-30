import Foundation

enum AppSettings {
    private static let onboardingCompletedKey = "hasCompletedOnboarding"
    private static let hideWidgetInstructionsKey = "hideWidgetInstructions"
    private static let reviewPromptDisabledKey = "reviewPromptDisabled"
    private static let reviewCompletedKey = "reviewCompleted"
    private static let hasPromptedReviewKey = "hasPromptedReview"
    private static let lastReviewPromptAtKey = "lastReviewPromptAt"
    private static let lastReviewPromptLaunchCountKey = "lastReviewPromptLaunchCount"
    private static let reviewStoreKitCountKey = "reviewStoreKitCount"
    private static let reviewStoreKitYearKey = "reviewStoreKitYear"
    private static let appLaunchCountKey = "appLaunchCount"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
    }

    /// Installed apps already have metrics and no onboarding flag. Don't cover that library.
    static func completeOnboardingForExistingLibrary(hasMetrics: Bool) {
        guard hasMetrics, !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
    }

    static var hideWidgetInstructions: Bool {
        get { UserDefaults.standard.bool(forKey: hideWidgetInstructionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideWidgetInstructionsKey) }
    }

    static var reviewPromptDisabled: Bool {
        get { UserDefaults.standard.bool(forKey: reviewPromptDisabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: reviewPromptDisabledKey) }
    }

    static var reviewCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: reviewCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: reviewCompletedKey) }
    }

    static var hasPromptedReview: Bool {
        get { UserDefaults.standard.bool(forKey: hasPromptedReviewKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasPromptedReviewKey) }
    }

    static var lastReviewPromptAt: Date? {
        get {
            let value = UserDefaults.standard.double(forKey: lastReviewPromptAtKey)
            guard value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastReviewPromptAtKey)
        }
    }

    static var lastReviewPromptLaunchCount: Int {
        get { UserDefaults.standard.integer(forKey: lastReviewPromptLaunchCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastReviewPromptLaunchCountKey) }
    }

    static var reviewStoreKitCount: Int {
        get { UserDefaults.standard.integer(forKey: reviewStoreKitCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: reviewStoreKitCountKey) }
    }

    static var reviewStoreKitYear: Int {
        get { UserDefaults.standard.integer(forKey: reviewStoreKitYearKey) }
        set { UserDefaults.standard.set(newValue, forKey: reviewStoreKitYearKey) }
    }

    static var appLaunchCount: Int {
        get { UserDefaults.standard.integer(forKey: appLaunchCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: appLaunchCountKey) }
    }
}
