import SwiftUI
import VVSI
import AnyMetricsShared

struct NewMetricView: View {

    @Binding
    var allowDismissed: Bool
    var callback: (Metric) -> Void

    var body: some View {
        MetricFormView(
            allowDismissed: $allowDismissed,
            action: { metric in
                callback(metric)
            })
        .navigationTitle(AnyMetricsStrings.Addmetric.titleNew)
        .navigationBarTitleDisplayMode(.inline)
    }

}

#if DEBUG

struct NewMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewMetricView(
                allowDismissed: .constant(true),
                callback: { _ in

                }
            )
            .environmentObject(ViewState(MainView.Interactor()))
            .preferredColorScheme(.dark)
        }
    }
}
#endif
