import SwiftUI
import VVSI
import AnyMetricsShared

struct EditMetricView: View {

    @Binding
    var allowDismissed: Bool
    let metric: Metric
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>
    var callback: (Metric) -> Void
    
    init(
        metric: Metric,
        allowDismissed: Binding<Bool>,
        callback: @escaping (Metric) -> Void
    ) {
        self._allowDismissed = allowDismissed
        self.metric = metric
        self.callback = callback
    }

    var body: some View {
        NavigationView {
            MetricFormView(
                allowDismissed: $allowDismissed,
                metric: metric,
                action: { metric in
                    callback(metric)
                    presentationMode.wrappedValue.dismiss()
            })
            .navigationTitle(AnyMetricsStrings.Metric.Actions.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(AnyMetricsStrings.Common.close) {
                    presentationMode.wrappedValue.dismiss()
                }
            }

        }
    }
}

#if DEBUG
struct EditMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditMetricView(
                metric: Mocks.getMockMetric(
                    title: "Preview",
                    measure: "pc",
                    type: .json,
                    typeRule: ParseRules(),
                    result: "0",
                    resultWithError: false
                ),
                allowDismissed: .constant(true)
            ) { _ in

            }
            .environmentObject(ViewState(MainView.Interactor()))
            .preferredColorScheme(.dark)
        }
    }
}
#endif
