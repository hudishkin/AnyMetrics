//
//  MetricReponseView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 30.06.2022.
//

import SwiftUI

fileprivate enum Constants {
    static let imageFAQ = Image(systemName: "questionmark.circle.fill")
    static let imageRefresh = Image(systemName: "arrow.clockwise")
    static let zero: CGFloat = 0
    static let faqSize: CGFloat = 20
    static let responsPadding = EdgeInsets(top: -50, leading: 20, bottom: 20, trailing: 20) //CGFloat = 20
    static let lengthLabelInset = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let lengthLabelBackground = R.color.secondaryText.color.opacity(0.5)
    static let lengthLabelCorner: CGFloat = 20
    static let infinityChar = "∞"
    static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
    static let responseFont = Font.system(size: 12, design: .monospaced)
    static let responsPaddingButton: CGFloat = -10
    static let mainButtonFont = Font.system(size: 17, weight: .semibold, design: .default)
    static let requestImage = R.image.request.image
    static let createNewIcon: CGFloat = 16
    static let buttonBackground = R.color.baseText.color
    static let buttonTextColor = R.color.addMetricTint.color
    static let requestButtonInset =  EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let requestButtonCorner: CGFloat = 24
    static let mainButtonCorner: CGFloat = 40
    static let opacityEnable: CGFloat = 1
    static let opacityDisable: CGFloat = 0.4
    static let borderWidth: CGFloat = 1
    static let paddingBottomForm: CGFloat = 60
    static let codeBottomPadding: CGFloat = -10
}

struct MetricReponseView: View {

    @Binding var allowDismissed: Bool
    @State var showNext = false

    @EnvironmentObject var viewModel: MetricViewModel
    var action: (Metric) -> Void

    private var typeCode: CodeView.CodeType {
        switch viewModel.typeMetric {
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
                    // MARK: - Response
                    VStack(alignment: .center) {

                        if viewModel.response.isEmpty {
                            VStack {
                                Button {
                                    self.viewModel.makeRequest()
                                } label: {
                                    HStack {
                                        Constants.requestImage
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(Constants.buttonBackground)
                                            .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                            .aspectRatio(contentMode: .fit)
                                        Text(R.string.localizable.addmetricButtonMakeRequest())
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
                                code: $viewModel.response,
                                codeType: .constant(self.typeCode))
                            .padding(.bottom, Constants.codeBottomPadding)
                            .frame(
                                    minWidth: 0,
                                    maxWidth: .infinity,
                                    minHeight: 0,
                                    maxHeight: .infinity)
                        }
                    }
                    .background(viewModel.response.isEmpty ? .clear : Color(uiColor: .systemBackground))
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
                                    text: self.$viewModel.parseRules)
                                .onChange(of: self.viewModel.parseRules) { newValue in
                                    self.viewModel.updateValue(rule: newValue)
                                }
                                .disableAutocorrection(true)

                            }

                            Picker(
                                R.string.localizable.addmetricFieldTypeParseRuleTitle(),
                                selection: $viewModel.typeRule) {
                                    ForEach(ParseRules.RuleType.allCases, id: \.self) { item in
                                    Text(item.localizedName).tag(item)
                                }
                            }
                            .pickerStyle(.automatic)
                            .onChange(of: self.viewModel.formatType) { _ in
                                self.viewModel.updateValue()
                            }
                            if viewModel.typeRule != .none {
                                HStack(alignment: .center, spacing: Constants.zero) {
                                    TextField( R.string.localizable.addmetricFieldRuleTypePlaceholder(),
                                        text: self.$viewModel.parseConfigurationValue)
                                    .onChange(of: self.viewModel.parseConfigurationValue) { _ in
                                        self.viewModel.updateValue()
                                    }
                                    .disableAutocorrection(true)
                                }

                                HStack(alignment: .center, spacing: Constants.zero) {
                                    Toggle(R.string.localizable.addmetricFieldCaseSensitive(), isOn: $viewModel.caseSensitive)
                                }
                            }

                        }
                        footer: {
                            if viewModel.typeRule == .contains {
                                VStack {
                                    Text(R.string.localizable.addmetricFieldRuleTypeContainsDescription())
                                }
                            } else if viewModel.typeRule == .equal {
                                VStack {
                                    Text(R.string.localizable.addmetricFieldRuleTypeEqualDescription())
                                }
                            }
                        }

                        if viewModel.typeRule == .none {
                            Section {
                                Picker(
                                    R.string.localizable.addmetricFieldValueType(),
                                    selection: $viewModel.formatType) {
                                    ForEach(MetricFormatterType.allCases, id: \.self) { item in
                                        Text(item.localizedName).tag(item)
                                    }
                                }
                                .pickerStyle(.automatic)
                                .onChange(of: self.viewModel.formatType) { _ in
                                    self.viewModel.updateValue()
                                }

                                if viewModel.formatType == .none {
                                    HStack(alignment: .center, spacing: 0) {
                                        Stepper(value: self.$viewModel.maxLengthValue, in:  0...Int.max) {
                                            HStack {
                                                Text(R.string.localizable.addmetricFieldMaxLength())
                                                Spacer()
                                                Text(maxLength())
                                                    .font(Constants.smallFont)
                                                    .padding(Constants.lengthLabelInset)
                                                    .foregroundColor(R.color.baseText.color)
                                                    .background(Constants.lengthLabelBackground)
                                                    .cornerRadius(Constants.lengthLabelCorner)
                                            }
                                        }
                                        .onChange(of: self.viewModel.maxLengthValue) { newValue in
                                            self.viewModel.updateValue(length: newValue)
                                        }
                                    }
                                }
                            } header: {
                                Text(R.string.localizable.addmetricSectionFormatSettings())
                            }
                        }


                        if viewModel.canSetupResponse && !viewModel.parseRules.isEmpty {
                            Section {
                                HStack(alignment: .top) {
                                    Text(R.string.localizable.addmetricFieldValue())
                                    Spacer()
                                    Text(getResultText())
                                        .foregroundColor(R.color.secondaryText.color)
                                        .lineLimit(1)
                                }

                            } header: {
                                Text(R.string.localizable.addmetricSectionResult())
                            }
                        }
                    }
                }.padding(.bottom, Constants.paddingBottomForm)

                HStack(alignment: .center, spacing: Constants.zero, content: {
                    NavigationLink(isActive: $showNext) {
                        MetricDisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewModel)
                    } label: {
                        Button(action: {
                            showNext = true
                        }, label: {
                            Spacer()
                            Text(R.string.localizable.addmetricButtonNext())
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
            .navigationTitle(R.string.localizable.addmetricTitleValue())
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.requestStatus == .loading {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.makeRequest()
                        } label: {
                            Constants.imageRefresh
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Link(R.string.localizable.commonFaq(), destination: AppConfig.Urls.rules)
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
        if viewModel.typeMetric == .json {
            return R.string.localizable.addmetricFieldJsonParseRulePlaceholder()
        }
        return R.string.localizable.addmetricFieldHtmlParseRulePlaceholder()
    }

    func getResultText() -> String {
        if viewModel.result.isEmpty && (viewModel.typeMetric == .checkStatus || viewModel.typeRule == .contains || viewModel.typeRule == .equal) {
            return String(describing: viewModel.resultWithError)
        }
        return viewModel.result.isEmpty ? "-" : viewModel.result
    }

    func maxLength() -> String {
        if viewModel.maxLengthValue == 0 {
            return Constants.infinityChar
        }else {
            return String(viewModel.maxLengthValue)
        }
    }

    func opacityButton() -> CGFloat {
        enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
    }

    func enableNextButton() -> Bool {
        !viewModel.parseRules.isEmpty && !viewModel.hasParseRuleError
    }
}


#if DEBUG
struct MetricReponseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricReponseView(allowDismissed: .constant(false),action: { _ in
                
            })
            .environmentObject(MetricViewModel())
            .preferredColorScheme(.light)
        }
    }
}
#endif
