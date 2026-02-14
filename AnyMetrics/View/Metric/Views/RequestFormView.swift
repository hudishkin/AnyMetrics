import SwiftUI
import VVSI
import AnyMetricsShared

extension MetricFormView {
    struct RequestFormView: View {

        @State
        var showAddHeader: Bool = false
        @EnvironmentObject
        var viewState: ViewState<MetricFormView.Interactor>

        var body: some View {
            Form {
                Section {
                    TextField(
                        AnyMetricsStrings.Addmetric.Field.urlPlaceholder,
                        text: binding(for: \.requestUrl, set: MetricFormView.VAction.setRequestUrl))
                    .disabled(viewState.state.requestStatus == .loading)
                    .disableAutocorrection(true)
                    Picker(
                        AnyMetricsStrings.Addmetric.Field.httpMethod,
                        selection: binding(for: \.httpMethodType, set: MetricFormView.VAction.setHTTPMethodType)) {
                            ForEach(HTTPMethodType.allCases, id: \.self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.automatic)

                    Picker(
                        AnyMetricsStrings.Addmetric.Field.typeMetric,
                        selection: binding(for: \.typeMetric, set: MetricFormView.VAction.setTypeMetric)) {
                            ForEach(TypeMetric.allCases, id: \.self) { item in
                                Text(item.localizedString).tag(item)
                            }
                        }
                        .pickerStyle(.automatic)
                } header: {
                    Text(AnyMetricsStrings.Addmetric.Section.requestSettings)
                }
                Section {
                    ForEach(viewState.state.httpHeaders.sorted(by: >), id: \.key) { item in
                        HStack(alignment: .center, spacing: Constants.zero) {
                            Button {
                                viewState.trigger(.removeHeader(name: item.key))
                            } label: {
                                Image(systemName: Constants.minusImageName)
                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            }.padding(Constants.httpHeadersInset)
                            Text(item.key)
                            Spacer()
                            Text(item.value)
                                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)

                        }
                    }
                    HStack(alignment: .center) {
                        Button {
                            self.showAddHeader = true
                        } label: {
                            HStack {
                                AnyMetricsAsset.Assets.plus.swiftUIImage
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                    .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                Text(AnyMetricsStrings.Addmetric.Button.addHttpHeader)
                                    .font(Constants.mainButtonFont)
                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            }
                        }
                        .sheet(isPresented: $showAddHeader) {
                            self.showAddHeader = false
                        } content: {
                            AddHeaderView(action: { headerName, headerValue in
                                viewState.trigger(.addHeader(name: headerName, value: headerValue))
                            })
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
                                    .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
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
                            Text(AnyMetricsStrings.Common.error)
                                .foregroundColor(.red)
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
                        .overlay(Rectangle().fill(LinearGradient(colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)], startPoint:  UnitPoint.top, endPoint: UnitPoint.bottom)))

                }
            }
            .navigationTitle(AnyMetricsStrings.Addmetric.titleRequest)
        }

        func opacityRequestButton() -> CGFloat {
            self.viewState.state.canMakeRequest ? Constants.opacityEnable : Constants.opacityDisable
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
