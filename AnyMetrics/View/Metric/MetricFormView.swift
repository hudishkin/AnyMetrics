import SwiftUI
import AnyMetricsShared
import VVSI

enum MetricFormEntry {
    case request
    case theme
}

struct MetricFormView: View {

    @Binding
    var allowDismissed: Bool

    @StateObject
    private var viewState: ViewState<Interactor>
    @StateObject
    private var requestViewState: ViewState<RequestFormView.Interactor>
    @State
    var showNext: Bool = false
    var formSession: MetricFormSession
    var entry: MetricFormEntry
    var action: (Metric) -> Void

    init(
        allowDismissed: Binding<Bool>,
        metric: Metric? = nil,
        formSession: MetricFormSession = .inactive,
        entry: MetricFormEntry = .request,
        action: @escaping (Metric) -> Void
    ) {
        self._allowDismissed = allowDismissed
        let requestInteractor = RequestFormView.Interactor(metric: metric)
        self._requestViewState = .init(wrappedValue: .init(requestInteractor))
        self._viewState = .init(wrappedValue: .init(.init(metric: metric, requestInteractor: requestInteractor)))
        self.formSession = formSession
        self.entry = entry
        self.action = action
    }

    var body: some View {
        Group {
            switch entry {
            case .request:
                requestStep
            case .theme:
                DisplayView(
                    allowDismissed: $allowDismissed,
                    action: action,
                    screenTitle: AnyMetricsStrings.Metric.Actions.editTheme
                )
                .environmentObject(viewState)
                .environmentObject(requestViewState)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            allowDismissed = false
        }
        .onDisappear {
            allowDismissed = true
        }
        .environment(\.metricFormSession, formSession)
    }

    private var requestStep: some View {
        ZStack(alignment: .bottomTrailing) {
            RequestFormView(
                screenTitle: viewState.state.isEdited
                    ? AnyMetricsStrings.Metric.Actions.editRequest
                    : AnyMetricsStrings.Addmetric.titleRequest
            )
            .environmentObject(requestViewState)

            HStack(alignment: .center, spacing: Constants.zero, content: {
                NavigationLink(isActive: $showNext) {
                    if requestViewState.state.resultKind == .image {
                        DisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
                            .environmentObject(requestViewState)
                    } else {
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
                    }
                } label: {
                    Button(action: {
                        showNext = true
                        let step = goesToDisplay ? AnalyticsEvents.FormStep.display : AnalyticsEvents.FormStep.value
                        formSession.advance(to: step)
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
    }

    func opacityButton() -> CGFloat {
        enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
    }

    func enableNextButton() -> Bool {
        requestViewState.state.canSetupResponse
    }

    private var goesToDisplay: Bool {
        if requestViewState.state.resultKind == .image { return true }
        return requestViewState.state.typeMetric == .checkStatus
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
