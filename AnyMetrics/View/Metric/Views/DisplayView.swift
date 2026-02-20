import SwiftUI
import VVSI
import AnyMetricsShared

extension MetricFormView {

    struct DisplayView: View {

        @Binding
        var allowDismissed: Bool
        @EnvironmentObject
        var viewState: ViewState<MetricFormView.Interactor>
        @EnvironmentObject
        var requestViewState: ViewState<RequestFormView.Interactor>
        var action: (Metric) -> Void

        var body: some View {

            ZStack(alignment: .bottomTrailing) {
                Form {
                    Section {
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.title)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.titlePlaceholder,
                                text: formBinding(for: \.title, set: MetricFormView.VAction.setTitle))
                            .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.paramMeasure)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.paramMeasurePlaceholder,
                                text: formBinding(for: \.measure, set: MetricFormView.VAction.setMeasure))
                            .multilineTextAlignment(.trailing)
                        }
                    } header: {
                        HStack(alignment: .center) {
                            MetricContentView(
                                metric: Metric(
                                    formState: viewState.state,
                                    requestState: requestViewState.state
                                ) ?? Metric.empty()
                            )
                                .frame(
                                    width: Constants.metricViewSize,
                                    height: Constants.metricViewSize,
                                    alignment: .center)
                                .background(
                                    RoundedRectangle(cornerRadius: Constants.metricViewCorner)
                                        .fill(Color(uiColor: .systemBackground))
                                        .padding(Constants.metricViewPadding))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }

                }
                HStack(alignment: .center, spacing: Constants.zero, content: {
                    Button(action: {
                        guard let metric = Metric(
                            formState: viewState.state,
                            requestState: requestViewState.state
                        ) else { return }
                        action(metric)

                    }, label: {
                        Spacer()
                        Text(viewState.state.isEdited ? AnyMetricsStrings.Addmetric.Button.save : AnyMetricsStrings.Addmetric.Button.add)
                            .font(Constants.mainButtonFont).padding()
                        Spacer()
                    })
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Constants.buttonTextColor)
                    .background(Constants.buttonBackground)
                    .cornerRadius(Constants.mainButtonCorner)
                    .disabled(!enableNextButton())
                    .opacity(opacityButton())
                })
                .padding()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle(AnyMetricsStrings.Addmetric.titleDisplay)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    allowDismissed = false
                }
            }
        }

        func opacityButton() -> CGFloat {
            enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
        }

        func enableNextButton() -> Bool {
            let formState = viewState.state
            let requestState = requestViewState.state
            return !formState.measure.isEmpty
                && !formState.title.isEmpty
                && requestState.requestUrl.isValidURL
                && (requestState.typeMetric == .checkStatus || !formState.parseRules.isEmpty)
        }

        private func formBinding<Value>(
            for keyPath: KeyPath<MetricFormView.VState, Value>,
            set action: @escaping (Value) -> MetricFormView.VAction
        ) -> Binding<Value> {
            Binding(
                get: { viewState.state[keyPath: keyPath] },
                set: { viewState.trigger(action($0)) }
            )
        }
    }

}
