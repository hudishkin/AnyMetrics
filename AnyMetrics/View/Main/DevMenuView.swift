#if DEBUG
import SwiftUI

struct DevMenuView: View {

    let onShowOnboarding: () -> Void

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
    DevMenuView(onShowOnboarding: {})
}
#endif
