#if DEBUG
import SwiftUI

struct DevMenuView: View {

    let onShowOnboarding: () -> Void
    let onShowReviewPrompt: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var showWidgetInstructions = false
    @State
    private var customURL = APIServerStore.shared.customURLString
    @State
    private var usesCustom = APIServerStore.shared.usesCustom
    @State
    private var selectedID = APIServerStore.shared.current.id
    @State
    private var customURLIsInvalid = false
    @State
    private var simulation = DevSettings.simulateGeneration

    var body: some View {
        NavigationView {
            List {
                Section(AnyMetricsStrings.DevMenu.server) {
                    ForEach(APIServer.builtIn) { server in
                        Button {
                            select(server)
                        } label: {
                            serverRow(
                                title: serverTitle(server),
                                subtitle: server.baseURL.absoluteString,
                                selected: !usesCustom && selectedID == server.id
                            )
                        }
                    }

                    serverRow(
                        title: AnyMetricsStrings.DevMenu.serverCustom,
                        subtitle: usesCustom ? APIServerStore.shared.current.baseURL.absoluteString : "",
                        selected: usesCustom
                    )

                    TextField(AnyMetricsStrings.DevMenu.serverUrlPlaceholder, text: $customURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: customURL) { _ in
                            customURLIsInvalid = false
                        }

                    Button(AnyMetricsStrings.DevMenu.serverApply) {
                        applyCustomURL()
                    }

                    if customURLIsInvalid {
                        Text(AnyMetricsStrings.DevMenu.serverInvalid)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Toggle(AnyMetricsStrings.DevMenu.simulation, isOn: $simulation)
                        .onChange(of: simulation) { value in
                            DevSettings.simulateGeneration = value
                        }
                } footer: {
                    Text(AnyMetricsStrings.DevMenu.simulationFooter)
                }

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
                WidgetInstructionsView(metricTitle: "Some value") { _ in
                    showWidgetInstructions = false
                }
            }
        }
    }

    private func serverTitle(_ server: APIServer) -> String {
        switch server.id {
        case APIServer.local.id:
            return AnyMetricsStrings.DevMenu.serverLocal
        default:
            return server.baseURL.host ?? server.id
        }
    }

    private func serverRow(title: String, subtitle: String, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
            }
        }
    }

    private func select(_ server: APIServer) {
        APIServerStore.shared.selectBuiltIn(server.id)
        syncSelection()
        Task { await AuthSession.shared.restore() }
    }

    private func applyCustomURL() {
        guard APIServerStore.shared.selectCustom(urlString: customURL) else {
            customURLIsInvalid = true
            return
        }
        syncSelection()
        Task { await AuthSession.shared.restore() }
    }

    private func syncSelection() {
        let store = APIServerStore.shared
        usesCustom = store.usesCustom
        selectedID = store.current.id
        customURL = store.customURLString
        customURLIsInvalid = false
    }
}

#Preview {
    DevMenuView(onShowOnboarding: {}, onShowReviewPrompt: {})
}

enum DevSettings {
    private static let simulationKey = "dev.generate.simulation"

    static var simulateGeneration: Bool {
        get { UserDefaults.standard.bool(forKey: simulationKey) }
        set { UserDefaults.standard.set(newValue, forKey: simulationKey) }
    }
}
#endif
