import Foundation

enum AppSettings {
    private static let onboardingCompletedKey = "hasCompletedOnboarding"
    private static let starterMetricInstalledKey = "hasInstalledStarterMetric"
    private static let hideWidgetInstructionsKey = "hideWidgetInstructions"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
    }

    static var hasInstalledStarterMetric: Bool {
        get { UserDefaults.standard.bool(forKey: starterMetricInstalledKey) }
        set { UserDefaults.standard.set(newValue, forKey: starterMetricInstalledKey) }
    }

    static var hideWidgetInstructions: Bool {
        get { UserDefaults.standard.bool(forKey: hideWidgetInstructionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideWidgetInstructionsKey) }
    }
}
