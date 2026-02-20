import SwiftUI
import AnyMetricsShared
import VVSI

struct MetricFormView: View {

    @Binding
    var allowDismissed: Bool

    @StateObject
    private var viewState: ViewState<Interactor>
    @StateObject
    private var requestViewState: ViewState<RequestFormView.Interactor>
    @State
    var showNext: Bool = false
    var action: (Metric) -> Void

    init(
        allowDismissed: Binding<Bool>,
        metric: Metric? = nil,
        action: @escaping (Metric) -> Void
    ) {
        self._allowDismissed = allowDismissed
        let requestInteractor = RequestFormView.Interactor(metric: metric)
        self._requestViewState = .init(wrappedValue: .init(requestInteractor))
        self._viewState = .init(wrappedValue: .init(.init(metric: metric, requestInteractor: requestInteractor)))
        self.action = action
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RequestFormView()
                .environmentObject(requestViewState)
            HStack(alignment: .center, spacing: Constants.zero, content: {
                NavigationLink(isActive: $showNext) {
                    switch requestViewState.state.typeMetric {
                    case .checkStatus:
                        DisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
                            .environmentObject(requestViewState)
                    case .json, .web:
                        MetricResponseView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
                            .environmentObject(requestViewState)
                    }
                } label: {
                    Button(action: {
                        showNext = true
                    }, label: {
                        Spacer()
                        Text(AnyMetricsStrings.Addmetric.Button.next)
                            .font(Constants.mainButtonFont).padding()
                        Spacer()
                    })
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Constants.buttonTextColor)
                    .background(Constants.buttonBackground)
                    .cornerRadius(Constants.mainButtonCorner)
                    .disabled(!enableNextButton())
                    .opacity(opacityButton())
                }
            })
            .padding()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            allowDismissed = false
        }
        .onDisappear {
            allowDismissed = true
        }
    }

    func opacityButton() -> CGFloat {
        enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
    }

    func enableNextButton() -> Bool {
        requestViewState.state.canSetupResponse
    }
}

#if DEBUG

struct MetricFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricFormView(
                allowDismissed: .constant(false),
                metric: Mocks.metricCheck,
                action: { _ in

                }
            )
            .preferredColorScheme(.light)
        }
    }
}

struct MetricDispayView_Previews: PreviewProvider {
    static var previews: some View {
        let requestInteractor = RequestFormView.Interactor()
        NavigationView {
            MetricFormView.DisplayView(
                allowDismissed: .constant(false),
                action: { _ in

                }
            )
            .environmentObject(ViewState(MetricFormView.Interactor(requestInteractor: requestInteractor)))
            .environmentObject(ViewState(requestInteractor))
            .preferredColorScheme(.light)
        }
    }
}
#endif
