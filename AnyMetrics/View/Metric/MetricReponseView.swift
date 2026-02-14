import SwiftUI
import AnyMetricsShared
import VVSI

fileprivate enum Constants {
    static let imageFAQ = Image(systemName: "questionmark.circle.fill")
    static let imageRefresh = Image(systemName: "arrow.clockwise")
    static let zero: CGFloat = 0
    static let faqSize: CGFloat = 20
    static let responsPadding = EdgeInsets(top: -50, leading: 20, bottom: 20, trailing: 20) //CGFloat = 20
    static let lengthLabelInset = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let lengthLabelBackground = AnyMetricsAsset.Assets.secondaryText.swiftUIColor.opacity(0.5)
    static let lengthLabelCorner: CGFloat = 20
    static let infinityChar = "∞"
    static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
    static let responseFont = Font.system(size: 12, design: .monospaced)
    static let responsPaddingButton: CGFloat = -10
    static let mainButtonFont = Font.system(size: 17, weight: .semibold, design: .default)
    static let requestImage = AnyMetricsAsset.Assets.request.swiftUIImage
    static let createNewIcon: CGFloat = 16
    static let buttonBackground = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let buttonTextColor = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
    static let requestButtonInset =  EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let requestButtonCorner: CGFloat = 24
    static let mainButtonCorner: CGFloat = 40
    static let opacityEnable: CGFloat = 1
    static let opacityDisable: CGFloat = 0.4
    static let borderWidth: CGFloat = 1
    static let paddingBottomForm: CGFloat = 60
    static let codeBottomPadding: CGFloat = -10
}

struct MetricResponseView: View {

    @Binding
    var allowDismissed: Bool
    @State
    var showNext = false

    @EnvironmentObject
    var viewState: ViewState<MetricFormView.Interactor>
    var action: (Metric) -> Void

    private var typeCode: CodeView.CodeType {
        switch viewState.state.typeMetric {
        case .web:
            return .html
        case .json, .checkStatus:
            return .json
        }
    }

    var body: some View {
        GeometryReader { geomentry in
            ZStack(alignment: .bottomTrailing) {
                VStack {
                    VStack(alignment: .center) {
                        if viewState.state.response.isEmpty {
                            VStack {
                                Button {
                                    self.viewState.trigger(.makeRequest)
                                } label: {
                                    HStack {
                                        Constants.requestImage
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Constants.buttonBackground)
                                            .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                            .aspectRatio(contentMode: .fit)
                                        Text(AnyMetricsStrings.Addmetric.Button.makeRequest)
                                            .font(Constants.mainButtonFont)
                                            .foregroundColor(Constants.buttonBackground)
                                    }
                                    .padding(Constants.requestButtonInset)
                                    .overlay(RoundedRectangle(cornerRadius: Constants.requestButtonCorner)
                                        .stroke(Constants.buttonBackground, lineWidth: Constants.borderWidth))
                                }
                            }
                            .frame(
                                    minWidth: 0,
                                    maxWidth: .infinity,
                                    minHeight: 0,
                                    maxHeight: .infinity)

                        } else {
                            CodeView(
                                code: Binding(
                                    get: { viewState.state.response },
                                    set: { _ in }
                                ),
                                codeType: .constant(self.typeCode))
                            .padding(.bottom, Constants.codeBottomPadding)
                            .frame(
                                    minWidth: 0,
                                    maxWidth: .infinity,
                                    minHeight: 0,
                                    maxHeight: .infinity)
                        }
                    }
                    .background(viewState.state.response.isEmpty ? .clear : Color(uiColor: .systemBackground))
                    .frame(
                        width: geomentry.size.width,
                        height: geomentry.size.height / 2.5,
                        alignment: .center)
                     .background(Color(uiColor: .systemGroupedBackground))


                    // MARK: - Form
                    Form {
                        Section {
                            HStack(alignment: .center, spacing: Constants.zero) {
                                TextField(
                                    getRulesPlaceholder(),
                                    text: binding(for: \.parseRules, set: MetricFormView.VAction.setParseRules))
                                .disableAutocorrection(true)
                            }

                            Picker(
                                AnyMetricsStrings.Addmetric.Field.typeParseRuleTitle,
                                selection: binding(for: \.typeRule, set: MetricFormView.VAction.setTypeRule)) {
                                    ForEach(ParseRules.RuleType.allCases, id: \.self) { item in
                                    Text(item.localizedName).tag(item)
                                }
                            }
                            .pickerStyle(.automatic)
                            if viewState.state.typeRule != .none {
                                HStack(alignment: .center, spacing: Constants.zero) {
                                    TextField(AnyMetricsStrings.Addmetric.Field.ruleTypePlaceholder,
                                        text: binding(for: \.parseConfigurationValue, set: MetricFormView.VAction.setParseConfigurationValue))
                                    .disableAutocorrection(true)
                                }

                                HStack(alignment: .center, spacing: Constants.zero) {
                                    Toggle(AnyMetricsStrings.Addmetric.Field.caseSensitive, isOn: binding(for: \.caseSensitive, set: MetricFormView.VAction.setCaseSensitive))
                                }
                            }

                        }
                        footer: {
                            if viewState.state.typeRule == .contains {
                                VStack {
                                    Text(AnyMetricsStrings.Addmetric.Field.ruleTypeContainsDescription)
                                }
                            } else if viewState.state.typeRule == .equal {
                                VStack {
                                    Text(AnyMetricsStrings.Addmetric.Field.ruleTypeEqualDescription)
                                }
                            }
                        }

                        if viewState.state.typeRule == .none {
                            Section {
                                Picker(
                                    AnyMetricsStrings.Addmetric.Field.valueType,
                                    selection: binding(for: \.formatType, set: MetricFormView.VAction.setFormatType)) {
                                    ForEach(MetricFormatterType.allCases, id: \.self) { item in
                                        Text(item.localizedName).tag(item)
                                    }
                                }
                                .pickerStyle(.automatic)

                                if viewState.state.formatType == .none {
                                    HStack(alignment: .center, spacing: 0) {
                                        Stepper(value: binding(for: \.maxLengthValue, set: MetricFormView.VAction.setMaxLengthValue), in:  0...Int.max) {
                                            HStack {
                                                Text(AnyMetricsStrings.Addmetric.Field.maxLength)
                                                Spacer()
                                                Text(maxLength())
                                                    .font(Constants.smallFont)
                                                    .padding(Constants.lengthLabelInset)
                                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                                    .background(Constants.lengthLabelBackground)
                                                    .cornerRadius(Constants.lengthLabelCorner)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                Text(AnyMetricsStrings.Addmetric.Section.formatSettings)
                            }
                        }


                        if viewState.state.canSetupResponse && !viewState.state.parseRules.isEmpty {
                            Section {
                                HStack(alignment: .top) {
                                    Text(AnyMetricsStrings.Addmetric.Field.value)
                                    Spacer()
                                    Text(getResultText())
                                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                                        .lineLimit(1)
                                }

                            } header: {
                                Text(AnyMetricsStrings.Addmetric.Section.result)
                            }
                        }
                    }
                }.padding(.bottom, Constants.paddingBottomForm)

                HStack(alignment: .center, spacing: Constants.zero, content: {
                    NavigationLink(isActive: $showNext) {
                        MetricFormView.DisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewState)
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

            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AnyMetricsStrings.Addmetric.titleValue)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewState.state.requestStatus == .loading {
                        ProgressView()
                    } else {
                        Button {
                            viewState.trigger(.makeRequest)
                        } label: {
                            Constants.imageRefresh
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Link(AnyMetricsStrings.Common.faq, destination: AppConfig.Urls.rules)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    allowDismissed = false
                }
            }
        }
    }

    func getRulesPlaceholder() -> String {
        if viewState.state.typeMetric == .json {
            return AnyMetricsStrings.Addmetric.Field.jsonParseRulePlaceholder
        }
        return AnyMetricsStrings.Addmetric.Field.htmlParseRulePlaceholder
    }

    func getResultText() -> String {
        if viewState.state.result.isEmpty
            && (viewState.state.typeMetric == .checkStatus
                || viewState.state.typeRule == .contains
                || viewState.state.typeRule == .equal) {
            return String(describing: viewState.state.resultWithError)
        }
        return viewState.state.result.isEmpty ? "-" : viewState.state.result
    }

    func maxLength() -> String {
        if viewState.state.maxLengthValue == 0 {
            return Constants.infinityChar
        }else {
            return String(viewState.state.maxLengthValue)
        }
    }

    func opacityButton() -> CGFloat {
        enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
    }

    func enableNextButton() -> Bool {
        !viewState.state.parseRules.isEmpty && !viewState.state.hasParseRuleError
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


#if DEBUG
struct MetricReponseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricResponseView(allowDismissed: .constant(false),action: { _ in
                
            })
            .environmentObject(ViewState(MetricFormView.Interactor()))
            .preferredColorScheme(.light)
        }
    }
}
#endif
