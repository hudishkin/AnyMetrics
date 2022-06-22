//
//  NewMetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
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
    static let mainButtonPadding: CGFloat = -16
    static let mainButtonCorner: CGFloat = 40
    static let mainButtonHeight: CGFloat = 52
    static let buttonBackground = R.color.addMetricTint.color
    static let buttonTextColor = R.color.baseText.color
    static let createNewIcon: CGFloat = 16
    static let requestImage = R.image.request.image
    static let imageFAQ = Image(systemName: "questionmark.circle.fill")
    static let faqSize: CGFloat = 20
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



struct NewMetricView: View {
    @Binding var allowDismissed: Bool
    @StateObject var viewModel = NewMetricViewModel()
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var mainViewModel: MainViewModel
    @State var showAddHeader: Bool = false

    var body: some View {
        Form {
            Section {
                TextField(
                    R.string.localizable.addmetricPlaceholderJsonUrl(),
                    text: $viewModel.requestUrl)
                .disabled(viewModel.loading)
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
                        }.padding(Constants.httpHeadersInset)

                        Text(item.key)
                        R.color.secondaryText.color.foregroundColor(R.color.secondaryText.color)
                        Spacer()
                        Text(item.value)

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
                    Spacer()
                    if viewModel.loadingRequest {
                        ProgressView()
                    } else {
                        EmptyView()
                    }
                }
                if viewModel.typeMetric == .checker {
                    HStack(alignment: .center) {
                        Circle()
                            .frame(width: 10, height: 10, alignment: .leading)
                            .foregroundColor(self.viewModel.hasRequestError ? R.color.metricGood.color : R.color.metricBad.color)
                        Text(checkerText())
                        Spacer()
                        if viewModel.loadingRequest {
                            ProgressView()
                        } else {
                            EmptyView()
                        }
                    }
                } else {
                    if viewModel.showRequestResult {
                        HStack(alignment: .center, spacing: 0) {
                            MetricResponseView(text: self.$viewModel.response)
                        }
                        HStack(alignment: .center, spacing: 0) {
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
                                    .frame(width: Constants.faqSize, height: Constants.faqSize, alignment: .center)
                                    .foregroundColor(R.color.baseText.color)

                            }
                        }

                        Picker(R.string.localizable.addmetricMetricValueFormat(), selection: $viewModel.formatType) {
                            ForEach(MetricFormatterType.allCases, id: \.self) { item in
                                Text(item.localizedName).tag(item)
                            }
                        }
                        .pickerStyle(.automatic)
                        .onChange(of: self.viewModel.formatType) { newValue in
                            self.viewModel.updateValue()
                        }

                        if viewModel.formatType == .none {
                            HStack(alignment: .center, spacing: Constants.zero) {
                                Stepper(
                                    lengthText(),
                                    value: self.$viewModel.maxLengthValue,
                                    in: Constants.lengthValueRange)
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
                HStack {
                    if viewModel.hasParseRuleError {
                        Text(R.string.localizable.addmetricErrorInvalidRule()).foregroundColor(.red)
                    }else {
                        if !viewModel.parseValue.isEmpty {
                            Text(R.string.localizable.addmetricValueDisplay(viewModel.parseValueByLength))
                        }

                    }
                }

            }

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
        }

        // MARK: Add button

        Section {
            EmptyView()
        } footer: {
            HStack(alignment: .center, spacing: Constants.zero, content: {
                Button(action: {
                    guard let metric = viewModel.getMetric() else { return }
                    mainViewModel.addMetric(metric: metric)
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Spacer()
                    Text(R.string.localizable.addmetricAdd())
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

        .navigationTitle(R.string.localizable.addmetricNewTitle())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
             allowDismissed = false
        }.onDisappear{
             allowDismissed = true
        }

    }

    func checkerText() -> String {
        if self.viewModel.hasRequestError {
            return "value-lifeless".localizedCapitalized
        }else {
            return "value-alive".localizedCapitalized
        }
    }

    func opacityButton() -> CGFloat {
        self.viewModel.canAddMetric ? 1.0 : 0.3
    }

    func lengthText() -> String {
        if viewModel.maxLengthValue == 0 {
            return R.string.localizable.addmetricNoLimitLength()
        }else {
            return R.string.localizable.addmetricMaxlength("\(viewModel.maxLengthValue)")
        }
    }
}


#if DEBUG
let placeholderValueMetric = Metric(id: UUID(), title: "SERVICE", paramName: "Value type", lastValue: "T", request: nil, type: .json, parseRules: nil, created: Date(), updated: nil)

struct MainEdit_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewMetricView(allowDismissed: .constant(true))
                .environmentObject(MainViewModel())
                .preferredColorScheme(.dark)
        }
    }
}
#endif
