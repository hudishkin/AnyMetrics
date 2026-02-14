import SwiftUI
import VVSI

@main
struct AnyMetricsApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
