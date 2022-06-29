//
//  MetricFormView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 28.06.2022.
//

import SwiftUI


fileprivate enum Constants {
    // MetricResponseView
    static let responseFont = Font.system(size: 12, design: .monospaced)
    static let responseViewMaxHeight: CGFloat = 200
    static let responseViewWidth = UIScreen.main.bounds.width - 42
    static let responseInset = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    static let minusImageName = "minus.circle.fill"
    static let pickerInset = EdgeInsets(top: -20, leading: -20, bottom: -10, trailing: -20)
    static let zero: CGFloat = 0
    static let httpHeadersInset = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)
    static let lengthValueRange = 0...Int.max
    static let mainButtonFont = Font.system(size: 17, weight: .semibold, design: .default)

    static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
    static let mainButtonPadding: CGFloat = -16
    static let mainButtonCorner: CGFloat = 40
    static let mainButtonHeight: CGFloat = 52
    static let buttonBackground = R.color.addMetricTint.color
    static let buttonTextColor = R.color.baseText.color
    static let createNewIcon: CGFloat = 16
    static let requestImage = R.image.request.image
    static let imageFAQ = Image(systemName: "questionmark.circle.fill")
    static let faqSize: CGFloat = 20
    static let opcityEnable: CGFloat = 1.0
    static let opcityDisable: CGFloat = 0.4
    static let lengthLabelInset = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let lengthLabelBackground = R.color.secondaryText.color.opacity(0.5)
    static let lengthLabelCorner: CGFloat = 20
    static let infinityChar = "∞"
    static let circleCheckerSize: CGFloat = 12
    static let checkerGoodBackground = Color.green
    static let checkerBadBackground = Color.red
}

// MARK: - MetricResponseView

struct MetricResponseView: View {

    @Binding var text: String

    var body: some View {
        ScrollView {
            VStack {
                if text.isEmpty {
                    Text(R.string.localizable.addmetricEmptyResponse())
                        .font(Constants.responseFont)
                        .foregroundColor(.gray)
                } else {
                    Text(text)
                        .font(Constants.responseFont)
                }
            }
            .frame(width: Constants.responseViewWidth, alignment: .leading)
        }
        .frame(maxHeight: Constants.responseViewMaxHeight)
        .padding(Constants.responseInset)
    }
}



struct MetricFormView: View {

    let mainButtonTitle: String
    @StateObject var viewModel: MetricViewModel
    var action: (Metric) -> Void

    @State var showAddHeader: Bool = false

    var body: some View {
        Form {
            Section {
                TextField(
                    R.string.localizable.addmetricPlaceholderJsonUrl(),
                    text: $viewModel.requestUrl)
                .disabled(viewModel.loading)
                .disableAutocorrection(true)
                Picker(
                    R.string.localizable.addmetricHttpMethod(),
                    selection: $viewModel.httpMethodType) {
                        ForEach(HTTPMethodType.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)

                Picker(
                    R.string.localizable.addmetricSelectType(),
                    selection: $viewModel.typeMetric) {
                        ForEach(TypeMetric.allCases, id: \.self) { item in
                            Text(item.localizedString).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)
            }
            Section {
                ForEach(viewModel.httpHeaders.sorted(by: >), id: \.key) { item in
                    HStack(alignment: .center, spacing: Constants.zero) {
                        Button {
                            viewModel.httpHeaders[item.key] = nil
                        } label: {
                            Image(systemName: Constants.minusImageName)
                                .foregroundColor(R.color.baseText.color)
                        }.padding(Constants.httpHeadersInset)

                        Text(item.key)

                        Spacer()
                        Text(item.value)
                            .foregroundColor(R.color.secondaryText.color)

                    }
                }
                HStack(alignment: .center) {
                    Button {
                        self.showAddHeader = true
                    } label: {
                        HStack {
                            R.image.plus.image
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(Constants.buttonTextColor)
                                .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                            Text(R.string.localizable.addmetricAddHeader())
                                .font(Constants.mainButtonFont)
                                .foregroundColor(Constants.buttonTextColor)
                        }
                    }
                    .sheet(isPresented: $showAddHeader) {
                        self.showAddHeader = false
                    } content: {
                        AddHeaderView(action: { headerName, headerValue in
                            viewModel.httpHeaders[headerName] = headerValue
                        })
                    }


                }
            } header: {
                Text(R.string.localizable.addmetricHttpHeaders())
            }
            Section {
                HStack(alignment: .center) {
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
                            Text(R.string.localizable.addmetricMakeRequest())
                                .font(Constants.mainButtonFont)
                                .foregroundColor(Constants.buttonTextColor)
                        }
                    }
                    .disabled(!viewModel.canMakeRequest)
                    .opacity(opacityRequestButton())
                    Spacer()
                    if viewModel.loadingRequest {
                        ProgressView()
                    } else {
                        EmptyView()
                    }
                }
                if viewModel.typeMetric == .checker {

                    // MARK: - Checker
                    if viewModel.showRequestResult {
                        HStack(alignment: .center) {
                            Circle()
                                .fill(self.viewModel.hasRequestError ? Constants.checkerBadBackground : Constants.checkerGoodBackground)
                                .frame(
                                    width: Constants.circleCheckerSize,
                                    height: Constants.circleCheckerSize,
                                    alignment: .leading)

                            Text(checkerText())
                            Spacer()
                            if viewModel.loadingRequest {
                                ProgressView()
                            } else {
                                EmptyView()
                            }
                        }
                    }

                } else {

                    // MARK: - Value Settings
                    if viewModel.showRequestResult {
                        HStack(alignment: .center, spacing: Constants.zero) {
                            MetricResponseView(text: self.$viewModel.response)
                        }
                        HStack(alignment: .center, spacing: Constants.zero) {
                            TextField(
                                R.string.localizable.addmetricParseRule(),
                                text: self.$viewModel.parseRules)
                            .onChange(of: self.viewModel.parseRules) { newValue in
                                self.viewModel.updateValue(rule: newValue)
                            }
                            .disableAutocorrection(true)
                            Link(destination: AppConfig.Urls.rules) {
                                Constants.imageFAQ
                                    .resizable()
                                    .frame(
                                        width: Constants.faqSize,
                                        height: Constants.faqSize,
                                        alignment: .center)
                                    .foregroundColor(R.color.baseText.color)

                            }
                        }
                        Picker(
                            R.string.localizable.addmetricMetricValueFormat(),
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
                            HStack(alignment: .center, spacing: Constants.zero) {
                                Stepper(value: self.$viewModel.maxLengthValue, in: Constants.lengthValueRange) {
                                    HStack {
                                        Text(R.string.localizable.addmetricMaxlength())
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

                    }
                }
            } header: {
                Text(R.string.localizable.addmetricValueTitle())
            } footer: {

                // MARK: - Metric Parse Result
                HStack {
                    if viewModel.hasParseRuleError {
                        Text(R.string.localizable.addmetricErrorInvalidRule()).foregroundColor(.red)
                    } else if !viewModel.parseValue.isEmpty {
                            Text(R.string.localizable.addmetricValueDisplay(viewModel.parseValueByLength))
                    }
                }
            }
            // MARK: - Details
            Section {
                HStack {
                    Text(R.string.localizable.addmetricMetricTitle())
                    TextField(
                        R.string.localizable.addmetricMetricTitleExample(),
                        text: $viewModel.title)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(R.string.localizable.addmetricTitleParamMetric())
                    TextField(
                        R.string.localizable.addmetricTitleParamExample(),
                        text: $viewModel.paramName)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(R.string.localizable.addmetricDetailAuthor())
                    TextField(
                        R.string.localizable.commonOptional(),
                        text: $viewModel.author)
                    .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text(R.string.localizable.addmetricDetailSite())
                    TextField(
                        R.string.localizable.commonOptional(),
                        text: $viewModel.website)
                    .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(R.string.localizable.addmetricDetails())
            }

            // MARK: - Add button
            Section {
                EmptyView()
            } footer: {
                HStack(alignment: .center, spacing: Constants.zero, content: {
                    Button(action: {
                        guard let metric = viewModel.getMetric() else { return }
                        action(metric)

                    }, label: {
                        Spacer()
                        Text(mainButtonTitle)
                            .font(Constants.mainButtonFont).padding()
                        Spacer()
                    })
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Constants.buttonTextColor)
                    .background(Constants.buttonBackground)
                    .cornerRadius(Constants.mainButtonCorner)
                    .disabled(!self.viewModel.canAddMetric)
                    .opacity(opacityButton())
                }).padding(Constants.mainButtonPadding)
            }
        }
    }

    func checkerText() -> String {
        if self.viewModel.hasRequestError {
            return R.string.localizable.metricValueBad()
        }else {
            return R.string.localizable.metricValueGood()
        }
    }

    func opacityButton() -> CGFloat {
        self.viewModel.canAddMetric ? Constants.opcityEnable : Constants.opcityDisable
    }

    func opacityRequestButton() -> CGFloat {
        self.viewModel.canMakeRequest ? Constants.opcityEnable : Constants.opcityDisable
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

struct MetricFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricFormView(mainButtonTitle: "Add", viewModel: MetricViewModel(), action: { _ in

            })
                .preferredColorScheme(.light)
        }
    }
}
#endif
