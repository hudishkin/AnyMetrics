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
    static let opacityEnable: CGFloat = 1.0
    static let opacityDisable: CGFloat = 0.4
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

struct MetricRequestForm: View {

    @State var showAddHeader: Bool = false
    @EnvironmentObject var viewModel: MetricViewModel

    var body: some View {
        Form {
            Section {
                TextField(
                    R.string.localizable.addmetricFieldUrlPlaceholder(),
                    text: $viewModel.requestUrl)
                .disabled(viewModel.requestStatus == .loading)
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
                HStack(alignment: .center) {
                    Button {
                        self.viewModel.makeRequest()
                    } label: {
                        HStack {
                            Constants.requestImage
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(R.color.baseText.color)
                                .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                .aspectRatio(contentMode: .fit)
                            Text(R.string.localizable.addmetricButtonMakeRequest())
                                .font(Constants.mainButtonFont)
                                .foregroundColor(R.color.baseText.color)
                        }
                    }
                    .disabled(!viewModel.canMakeRequest)
                    .opacity(opacityRequestButton())
                    Spacer()
                    switch viewModel.requestStatus {
                    case .error:
                        Text(R.string.localizable.commonError())
                            .foregroundColor(.red)
                    case .loading:
                        ProgressView()
                    case .success:
                        Text(R.string.localizable.commonOk())
                            .foregroundColor(.green)
                    case .none:
                        EmptyView()
                    }

                }
            } footer: {
                VStack {
                    Text(viewModel.response)
                        .font(Constants.responseFont)
                        .foregroundColor(R.color.secondaryText.color)

                }.frame(maxHeight: 300)
                    .overlay(Rectangle().fill(LinearGradient(colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)], startPoint:  UnitPoint.top, endPoint: UnitPoint.bottom)))

            }
        }
        .navigationTitle(R.string.localizable.addmetricTitleRequest())
    }



    func opacityRequestButton() -> CGFloat {
        self.viewModel.canMakeRequest ? Constants.opacityEnable : Constants.opacityDisable
    }
}

struct MetricDisplayView: View {

    @Binding var allowDismissed: Bool
    @EnvironmentObject var viewModel: MetricViewModel
    var action: (Metric) -> Void

    var body: some View {

        ZStack(alignment: .bottomTrailing) {
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
                } header: {
                    if let metric = getMetric() {
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
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                }

            }
            HStack(alignment: .center, spacing: Constants.zero, content: {
                Button(action: {
                    guard let metric = viewModel.getMetric() else { return }
                    action(metric)
                    
                }, label: {
                    Spacer()
                    Text(viewModel.isEdited ? R.string.localizable.addmetricButtonSave() : R.string.localizable.addmetricButtonAdd())
                        .font(Constants.mainButtonFont).padding()
                    Spacer()
                })
                .frame(maxWidth: .infinity)
                .foregroundColor(Constants.buttonTextColor)
                .background(Constants.buttonBackground)
                .cornerRadius(Constants.mainButtonCorner)
                .disabled(!enableNextButton())
                .opacity(opacityButton())
            })
            .padding()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle(R.string.localizable.addmetricTitleDisplay())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                allowDismissed = false
            }
        }
    }

    func getMetric() -> Metric {
        return viewModel.getMetric() ?? Mocks.getMockMetric(
            title: viewModel.title,
            measure: viewModel.measure,
            type: viewModel.typeMetric,
            typeRule: ParseRules(
                parseRules: viewModel.parseConfigurationValue,
                type: viewModel.typeRule,
                value: viewModel.paramEqualTo,
                caseSensitive: viewModel.caseSensitive),
            result: viewModel.result,
            resultWithError: viewModel.resultWithError)
    }

    func opacityButton() -> CGFloat {
        enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
    }

    func enableNextButton() -> Bool {
        viewModel.canAddMetric
    }
}

struct MetricFormView: View {

    @Binding var allowDismissed: Bool

    let mainButtonTitle: String
    @StateObject var viewModel: MetricViewModel
    @State var showNext: Bool = false
    var action: (Metric) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MetricRequestForm()
                .environmentObject(viewModel)
            HStack(alignment: .center, spacing: Constants.zero, content: {
                NavigationLink(isActive: $showNext) {
                    switch viewModel.typeMetric {
                    case .checkStatus:
                        MetricDisplayView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewModel)
                    case .json, .web:
                        MetricReponseView(allowDismissed: $allowDismissed, action: action)
                            .environmentObject(viewModel)
                    }
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
        }.ignoresSafeArea(.keyboard, edges: .bottom)
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
        viewModel.canSetupResponse
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

struct MetricDispayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetricDisplayView(allowDismissed: .constant(false),action: { _ in
                
            })
                .environmentObject(MetricViewModel())
                .preferredColorScheme(.light)
        }
    }
}
#endif

