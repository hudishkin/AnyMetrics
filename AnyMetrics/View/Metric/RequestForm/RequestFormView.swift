import SwiftUI
import VVSI
import AnyMetricsShared

struct RequestFormView: View {

    @EnvironmentObject
    var viewState: ViewState<RequestFormView.Interactor>

    @State
    private var activeSheet: HeaderSheet?

    var body: some View {
        Form {
            Section {
                TextField(
                    AnyMetricsStrings.Addmetric.Field.urlPlaceholder,
                    text: binding(for: \.requestUrl, set: VAction.setRequestUrl))
                .disabled(viewState.state.requestStatus == .loading)
                .disableAutocorrection(true)
                Picker(
                    AnyMetricsStrings.Addmetric.Field.httpMethod,
                    selection: binding(for: \.httpMethodType, set: VAction.setHTTPMethodType)) {
                        ForEach(HTTPMethodType.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)

                Picker(
                    AnyMetricsStrings.Addmetric.Field.typeMetric,
                    selection: binding(for: \.typeMetric, set: VAction.setTypeMetric)) {
                        ForEach(TypeMetric.allCases, id: \.self) { item in
                            Text(item.localizedString).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)

                Picker(
                    AnyMetricsStrings.Addmetric.Field.refreshInterval,
                    selection: binding(for: \.refreshInterval, set: VAction.setRefreshInterval)) {
                        ForEach(RefreshInterval.allCases) { item in
                            Text(item.localizedString).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)

            } header: {
                Text(AnyMetricsStrings.Addmetric.Section.requestSettings)
            }
            if viewState.state.httpMethodType.hasBody {
                Section {
                    TextEditor(text: binding(for: \.requestBody, set: VAction.setRequestBody))
                        .frame(minHeight: Constants.requestBodyMinHeight)
                        .font(Constants.responseFont)
                        .disableAutocorrection(true)
                } header: {
                    Text(AnyMetricsStrings.Addmetric.Field.requestBody)
                }
            }
            Section {
                ForEach(viewState.state.httpHeaders.sorted(by: >), id: \.key) { item in
                    Button {
                        activeSheet = .edit(key: item.key, value: item.value)
                    } label: {
                        HStack(alignment: .center, spacing: Constants.zero) {
                            Text(item.key)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            Spacer()
                            Text(item.value)
                                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                        }
                    }
                }
                HStack(alignment: .center) {
                    Button {
                        activeSheet = .add
                    } label: {
                        HStack {
                            AnyMetricsAsset.Assets.plus.swiftUIImage
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                .frame(width: Constants.createNewIcon, height: Constants.createNewIcon)
                            Text(AnyMetricsStrings.Addmetric.Button.addHttpHeader)
                                .font(Constants.mainButtonFont)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        }
                    }
                }
            } header: {
                Text(AnyMetricsStrings.Addmetric.Section.httpHeaders)
            }

            Section {
                HStack(alignment: .center) {
                    Button {
                        self.viewState.trigger(.makeRequest)
                    } label: {
                        HStack {
                            Constants.requestImage
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                .frame(width: Constants.createNewIcon, height: Constants.createNewIcon)
                                .aspectRatio(contentMode: .fit)
                            Text(AnyMetricsStrings.Addmetric.Button.makeRequest)
                                .font(Constants.mainButtonFont)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        }
                    }
                    .disabled(!viewState.state.canMakeRequest)
                    .opacity(opacityRequestButton())
                    Spacer()
                    switch viewState.state.requestStatus {
                    case .error:
                        Text(viewState.state.errorMessage.isEmpty
                             ? AnyMetricsStrings.Common.error
                             : viewState.state.errorMessage)
                            .foregroundColor(AnyMetricsAsset.Assets.red.swiftUIColor)
                            .font(.caption)
                            .lineLimit(3)
                            .multilineTextAlignment(.trailing)
                    case .loading:
                        ProgressView()
                    case .success:
                        Text(AnyMetricsStrings.Common.ok)
                            .foregroundColor(.green)
                    case .none:
                        EmptyView()
                    }

                }
            } footer: {
                VStack {
                    Text(viewState.state.response)
                        .font(Constants.responseFont)
                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)

                }.frame(maxHeight: 300)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(uiColor: .systemGroupedBackground).opacity(0),
                                        Color(uiColor: .systemGroupedBackground)
                                    ],
                                    startPoint: UnitPoint.top,
                                    endPoint: UnitPoint.bottom
                                )
                            )
                    )
            }
        }
        .navigationTitle(AnyMetricsStrings.Addmetric.titleRequest)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                AddHeaderView(mode: .add) { headerName, headerValue in
                    viewState.trigger(.addHeader(name: headerName, value: headerValue))
                }
            case .edit(let key, let value):
                AddHeaderView(
                    mode: .edit,
                    headerName: key,
                    headerValue: value,
                    onDelete: {
                        viewState.trigger(.removeHeader(name: key))
                    }
                ) { newName, newValue in
                    viewState.trigger(.editHeader(
                        oldName: key,
                        newName: newName,
                        newValue: newValue
                    ))
                }
            }
        }
    }

    private func opacityRequestButton() -> CGFloat {
        viewState.state.canMakeRequest ? Constants.opacityEnable : Constants.opacityDisable
    }

    private func binding<Value>(
        for keyPath: KeyPath<VState, Value>,
        set action: @escaping (Value) -> VAction
    ) -> Binding<Value> {
        Binding(
            get: { viewState.state[keyPath: keyPath] },
            set: { viewState.trigger(action($0)) }
        )
    }
}

extension RequestFormView {
    enum HeaderSheet: Identifiable {
        case add
        case edit(key: String, value: String)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let key, _): return "edit-\(key)"
            }
        }
    }
}

private extension RequestFormView {
    enum Constants {
        static let responseFont = Font.system(size: 12, design: .monospaced)
        static let zero: CGFloat = 0
        static let mainButtonFont = Font.body.weight(.semibold)
        static let createNewIcon: CGFloat = 16
        static let requestImage = AnyMetricsAsset.Assets.request.swiftUIImage
        static let requestBodyMinHeight: CGFloat = 100
        static let opacityEnable: CGFloat = 1.0
        static let opacityDisable: CGFloat = 0.4
    }
}
