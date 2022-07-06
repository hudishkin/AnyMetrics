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
    static let responsPadding: CGFloat = 20
    static let lengthLabelInset = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let lengthLabelBackground = R.color.secondaryText.color.opacity(0.5)
    static let lengthLabelCorner: CGFloat = 20
    static let infinityChar = "∞"
    static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
    static let responseFont = Font.system(size: 12, design: .monospaced)
    static let responsPaddingButton: CGFloat = -10
    static let buttonTextColor = R.color.baseText.color
    static let mainButtonFont = Font.system(size: 17, weight: .semibold, design: .default)
    static let requestImage = R.image.request.image
    static let createNewIcon: CGFloat = 16
    static let buttonBackground = R.color.addMetricTint.color
    static let requestButtonInset =  EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let requestButtonCorner: CGFloat = 24
}

struct MetricReponseView: View {


    @Binding var allowDismissed: Bool
    @EnvironmentObject var viewModel: MetricViewModel

    var body: some View {
        GeometryReader { geomentry in
            VStack {

                // MARK: - Response
                ScrollView {
                    VStack(alignment: .center) {
                        if viewModel.response.isEmpty {
                            Text(R.string.localizable.addmetricTextNoResponse())
                                .font(Constants.responseFont)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            Spacer(minLength: 40)

                            Button {
                                self.viewModel.makeRequest()
                            } label: {
                                HStack {
                                    Constants.requestImage
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Constants.buttonTextColor)
                                        .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                        .aspectRatio(contentMode: .fit)
                                    Text(R.string.localizable.addmetricButtonMakeRequest())
                                        .font(Constants.mainButtonFont)
                                        .foregroundColor(Constants.buttonTextColor)
                                }
                                .padding(Constants.requestButtonInset)
                                .background(Constants.buttonBackground)
                                .cornerRadius(Constants.requestButtonCorner)
                            }
                        } else {
                            Text(viewModel.response)
                                .font(Constants.responseFont)
                                .textCase(.none)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                        }
                    }
                    .padding(Constants.responsPadding)
                    .background(viewModel.response.isEmpty ? .clear : Color(uiColor: .systemBackground))

                }
                .frame(
                    width: geomentry.size.width,
                    height: geomentry.size.height / 2,
                    alignment: .center)
                .background(Color(uiColor: .systemGroupedBackground))
                .padding(.bottom, Constants.responsPaddingButton)

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

                    } footer: {
                        if viewModel.typeRule == .contains {
                            Text(R.string.localizable.addmetricFieldRuleTypeContainsDescription())
                        } else if viewModel.typeRule == .equal {
                            Text(R.string.localizable.addmetricFieldRuleTypeEqualDescription())
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
                }

            }
            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {

                    if viewModel.loadingRequest {
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
        }

        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                allowDismissed = false
            }
        }
    }

    func getRulesPlaceholder() -> String {
        if viewModel.typeMetric == .json {
            return R.string.localizable.addmetricFieldJsonParseRulePlaceholder()
        }
        return R.string.localizable.addmetricFieldHtmlParseRulePlaceholder()
    }

    func maxLength() -> String {
        if viewModel.maxLengthValue == 0 {
            return Constants.infinityChar
        }else {
            return String(viewModel.maxLengthValue)
        }
    }
}


#if DEBUG
struct MetricReponseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricReponseView(allowDismissed: .constant(true))
                .environmentObject(MetricViewModel())
                .preferredColorScheme(.light)
        }
    }
}
#endif
