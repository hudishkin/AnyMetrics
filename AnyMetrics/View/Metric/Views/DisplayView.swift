import SwiftUI
import VVSI
import AnyMetricsShared

extension MetricFormView {
    
    struct DisplayView: View {

        @Binding
        var allowDismissed: Bool
        @EnvironmentObject
        var viewState: ViewState<MetricFormView.Interactor>
        var action: (Metric) -> Void

        var body: some View {

            ZStack(alignment: .bottomTrailing) {
                Form {
                    Section {
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.title)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.titlePlaceholder,
                                text: binding(for: \.title, set: MetricFormView.VAction.setTitle))
                            .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.paramMeasure)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.paramMeasurePlaceholder,
                                text: binding(for: \.measure, set: MetricFormView.VAction.setMeasure))
                            .multilineTextAlignment(.trailing)
                        }
                    } header: {
                        HStack(alignment: .center) {
                            MetricContentView(metric: .init(with: viewState.state) ?? Metric.empty())
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
                        guard let metric = Metric(with: viewState.state) else { return }
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
            viewState.state.canAddMetric
        }

        private func binding<Value>(
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
