#if DEBUG
import SwiftUI

struct DevMenuView: View {

    let onShowOnboarding: () -> Void
    let onShowReviewPrompt: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showWidgetInstructions = false

    var body: some View {
        NavigationView {
            List {
                Button(AnyMetricsStrings.DevMenu.showOnboarding) {
                    dismiss()
                    onShowOnboarding()
                }

                Button(AnyMetricsStrings.DevMenu.showWidgetInstructions) {
                    showWidgetInstructions = true
                }

                Button(AnyMetricsStrings.DevMenu.showReviewPrompt) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onShowReviewPrompt()
                    }
                }

                Button(AnyMetricsStrings.DevMenu.resetReview) {
                    ReviewHandler.reset()
                }
            }
            .navigationTitle(AnyMetricsStrings.DevMenu.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AnyMetricsStrings.Common.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showWidgetInstructions) {
                WidgetInstructionsView(metricTitle: "Demo") {
                    showWidgetInstructions = false
                }
            }
        }
    }
}

#Preview {
    DevMenuView(onShowOnboarding: {}, onShowReviewPrompt: {})
}
#endif
