import SwiftUI
import AnyMetricsShared
import VVSI

struct MetricFormView: View {

    @Binding
    var allowDismissed: Bool

    @StateObject
    private var viewState: ViewState<Interactor>
    @State
    var showNext: Bool = false
    var action: (Metric) -> Void

    init(
        allowDismissed: Binding<Bool>,
        metric: Metric? = nil,
        action: @escaping (Metric) -> Void
    ) {
        self._allowDismissed = allowDismissed
        self._viewState = .init(wrappedValue: .init(.init(metric: metric)))
        self.action = action
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RequestFormView()
                .environmentObject(viewState)
            HStack(alignment: .center, spacing: Constants.zero, content: {
                NavigationLink(isActive: $showNext) {
                    switch viewState.state.typeMetric {
                    case .checkStatus:
                        DisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
                    case .json, .web:
                        MetricResponseView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
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
        viewState.state.canSetupResponse
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
        NavigationView {
            MetricFormView.DisplayView(
                allowDismissed: .constant(false),
                action: { _ in

                }
            )
            .environmentObject(ViewState(MetricFormView.Interactor()))
            .preferredColorScheme(.light)
        }
    }
}
#endif

