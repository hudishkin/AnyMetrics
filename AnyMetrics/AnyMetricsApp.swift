import SwiftUI
import VVSI

@main
struct AnyMetricsApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .task {
                    guard !isPreview else { return }
                    await AuthSession.shared.restore()
                    await GenerationJobService.shared.resume()
                }
        }
    }
}
