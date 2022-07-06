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
    static let buttonBackground = R.color.baseText.color
    static let buttonTextColor = R.color.addMetricTint.color
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
    static let circleConfigureSize: CGFloat = 8
    static let checkerGoodBackground = Color.green
    static let checkerBadBackground = Color.red
    static let metricViewSize: CGFloat = 200
    static let metricViewCorner: CGFloat = 42
    static let metricViewPadding: CGFloat = -10
}


struct MetricFormView: View {

    @Binding var allowDismissed: Bool

    let mainButtonTitle: String
    @StateObject var viewModel: MetricViewModel
    var action: (Metric) -> Void

    @State var showAddHeader: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(R.string.localizable.addmetricFieldTitle())
                    TextField(
                        R.string.localizable.addmetricFieldTitlePlaceholder(),
                        text: $viewModel.title)
                    .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(R.string.localizable.addmetricFieldParamMeasure())
                    TextField(
                        R.string.localizable.addmetricFieldParamMeasurePlaceholder(),
                        text: $viewModel.measure)
                    .multilineTextAlignment(.trailing)
                }
            }

            Section {
                TextField(
                    R.string.localizable.addmetricFieldUrlPlaceholder(),
                    text: $viewModel.requestUrl)
                .disabled(viewModel.loading)
                .disableAutocorrection(true)
                Picker(
                    R.string.localizable.addmetricFieldHttpMethod(),
                    selection: $viewModel.httpMethodType) {
                        ForEach(HTTPMethodType.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)

                Picker(
                    R.string.localizable.addmetricFieldTypeMetric(),
                    selection: $viewModel.typeMetric) {
                        ForEach(TypeMetric.allCases, id: \.self) { item in
                            Text(item.localizedString).tag(item)
                        }
                    }
                    .pickerStyle(.automatic)
            } header: {
                Text(R.string.localizable.addmetricSectionRequestSettings())
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
                                .foregroundColor(R.color.baseText.color)
                                .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                            Text(R.string.localizable.addmetricButtonAddHttpHeader())
                                .font(Constants.mainButtonFont)
                                .foregroundColor(R.color.baseText.color)
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
                Text(R.string.localizable.addmetricSectionHttpHeaders())
            }
            Section {
                if viewModel.typeMetric == .checkStatus {
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
                                Text(R.string.localizable.addmetricButtonMakeRequest())
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
                    HStack {
                        NavigationLink {
                            MetricReponseView(allowDismissed: $allowDismissed)
                                .environmentObject(viewModel)
                        } label: {
                            Text(R.string.localizable.addmetricFieldValueConfigure())
                            Spacer()
                            if viewModel.parseRules.isEmpty {
                                Circle()
                                    .fill(Constants.checkerBadBackground)
                                    .frame(
                                        width: Constants.circleConfigureSize,
                                        height: Constants.circleConfigureSize,
                                        alignment: .leading)
                            }

                        }

                    }
                }
            } header: {
                Text(R.string.localizable.addmetricSectionValueSettings())
            } footer: {
                if let metric = viewModel.getMetric() ?? Mocks.metricEmpty {
                    HStack(alignment: .center) {
                        MetricContentView(metric: metric)
                            .frame(
                                width: Constants.metricViewSize,
                                height: Constants.metricViewSize,
                                alignment: .center)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.metricViewCorner)
                                    .fill(Color(uiColor: .systemBackground))
                                    .padding(Constants.metricViewPadding))
                            .opacity(viewModel.canAddMetric ? 1.0 : 0.5)

                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
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
        .onAppear {
            allowDismissed = false
        }
        .onDisappear {
            allowDismissed = true
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

    
}



#if DEBUG

struct MetricFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricFormView(allowDismissed: .constant(false), mainButtonTitle: "Add", viewModel: MetricViewModel(), action: { _ in

            })
                .preferredColorScheme(.light)
        }
    }
}
#endif
