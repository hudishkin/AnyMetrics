import SwiftUI
import VVSI
import AnyMetricsShared

extension MetricFormView {

    struct DisplayView: View {

        @Binding
        var allowDismissed: Bool
        @State
        private var showSaveError = false
        @EnvironmentObject
        var viewState: ViewState<MetricFormView.Interactor>
        @EnvironmentObject
        var requestViewState: ViewState<RequestFormView.Interactor>
        var action: (Metric) -> Void

        var body: some View {

            ZStack(alignment: .bottomTrailing) {
                Form {
                    Section {
                        designCarousel
                    } header: {
                        EmptyView()
                    }

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
                    }
                }
                HStack(alignment: .center, spacing: Constants.zero, content: {
                    Button(action: {
                        guard let metric = Metric(
                            formState: viewState.state,
                            requestState: requestViewState.state
                        ) else {
                            showSaveError = true
                            return
                        }
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
            .alert(AnyMetricsStrings.Common.error, isPresented: $showSaveError) {
                Button(AnyMetricsStrings.Common.ok, role: .cancel) {}
            } message: {
                Text(AnyMetricsStrings.Addmetric.Error.cannotSave)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    allowDismissed = false
                }
            }
        }

        private var designCarousel: some View {
            VStack(spacing: 0) {
                TabView(selection: designBinding) {
                    ForEach(WidgetDesign.allCases) { design in
                        VStack(spacing: 12) {
                            MetricContentView(metric: previewMetric(for: design))
                                .frame(
                                    width: Constants.metricViewSize,
                                    height: Constants.metricViewSize,
                                    alignment: .center)
                                .background(
                                    RoundedRectangle(cornerRadius: Constants.metricViewCorner)
                                        .fill(Color(uiColor: .systemBackground))
                                        .padding(Constants.metricViewPadding))
                        }
                        .tag(design)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: Constants.designCarouselHeight)
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        private var designBinding: Binding<WidgetDesign> {
            formBinding(for: \.widgetDesign, set: MetricFormView.VAction.setWidgetDesign)
        }

        private func previewMetric(for design: WidgetDesign) -> Metric {
            let formState = viewState.state
            let requestState = requestViewState.state

            return Metric(
                id: formState.id,
                title: formState.title.isEmpty ? "—" : formState.title,
                measure: formState.measure,
                type: requestState.typeMetric,
                result: formState.result.isEmpty ? previewPlaceholderValue : formState.result,
                resultWithError: formState.resultWithError,
                formatter: .init(format: formState.formatType, length: formState.maxLengthValue),
                rules: .init(
                    parseRules: formState.parseRules,
                    type: formState.typeRule,
                    value: formState.parseConfigurationValue,
                    caseSensitive: formState.caseSensitive),
                widgetDesign: design
            )
        }

        private var previewPlaceholderValue: String {
            switch requestViewState.state.typeMetric {
            case .checkStatus:
                return viewState.state.resultWithError ? "false" : "true"
            default:
                return "1,234"
            }
        }

        func opacityButton() -> CGFloat {
            enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
        }

        func enableNextButton() -> Bool {
            Metric.canSave(from: viewState.state, requestState: requestViewState.state)
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
