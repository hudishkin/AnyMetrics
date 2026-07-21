import SwiftUI
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics

let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        guard !isPreview else { return true }

        FirebaseApp.configure()
        return true
    }

}
