//
//  MainView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import SwiftyJSON
import AnyMetricsShared



fileprivate enum Constants {
    static let fontTitle: Font = Font.system(size: 19, weight: .heavy, design: .default)
    static let fontPlaceholder: Font = Font.system(size: 16, weight: .regular, design: .default)
    static let padding: CGFloat = 10
    static let titleInset = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    static let infoInset = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    static let spacing: CGFloat = {
        AppConfig.isiOSAppOnMac ? 20 : 10
    }()
    static let size: CGFloat = {
        if AppConfig.isiOSAppOnMac {
            return 260
        }
        return (UIScreen.main.bounds.width / CGFloat(Constants.collumns.count)) - (Self.spacing * 2)

    }()
    static let heightPlaceholder: CGFloat = (UIScreen.main.bounds.height) - (Self.spacing * 2)
    static let zIndexTitle: CGFloat = 999
    static let titleCorner: CGFloat = 8
    static let topPadding: CGFloat = 58
    static let bottomPadding: CGFloat = 58
    static let scrollViewInset = EdgeInsets(top: 0, leading: Constants.padding, bottom: 0, trailing: Constants.padding)
    static let addButtonPadding: CGFloat = 14
    static let addButtonSize: CGFloat = {  AppConfig.isiOSAppOnMac ? 82 : 62 }()
    static let addButtonCorner: CGFloat = Self.addButtonSize / 2
    static let collumns: [GridItem] = {

        if AppConfig.isiOSAppOnMac {
            return [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        } else {
            return [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        }
    }()
}

struct MainView: View {

    @ObservedObject var viewModel: MainViewModel
    @State var showSheet = false
    @State var allowDismissed = true
    @State var showActionMenu = false

    let columns = Constants.collumns

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Header
                Button {
                    showSheet(activeSheet: .info)
                } label: {
                    Text(L10n.appName())
                        .font(Constants.fontTitle)
                        .foregroundColor(AssetColor.baseText)
                        .padding(Constants.titleInset)
                        .background(.ultraThinMaterial)
                        .cornerRadius(Constants.titleCorner)
                }
                .padding(Constants.padding)
                .zIndex(Constants.zIndexTitle)

                // MARK: - Content
                ScrollView {
                    Spacer(minLength: Constants.topPadding)
                    LazyVGrid(columns: columns, spacing: Constants.spacing) {
                        ForEach(viewModel.metrics.values.sorted(by: { $0.created > $1.created })) { metric in
                            MetricView(metric: metric, refreshMetric: { uuid in
                                viewModel.updateMetric(id: uuid)
                            }, deletehMetric: { uuid in
                                viewModel.removeMetric(id: uuid)
                            }, editMetric: { metric in
                                showSheet(activeSheet: .editMetric(metric))
                            })
                                .frame(width: Constants.size,
                                       height: Constants.size)

                        }
                    }

                    Spacer(minLength: Constants.bottomPadding)
                }
            }

            // MARK: - Add Button
            Button {
                ImpactHelper.impactButton()
                showSheet(activeSheet: .addMetrics)

            } label: {
                AssetImage.plus
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AssetColor.baseText)
                    .padding(Constants.addButtonPadding)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(Constants.addButtonCorner)
            .frame(width: Constants.addButtonSize, height: Constants.addButtonSize)
            .padding()

            if viewModel.metrics.isEmpty {

                VStack {
                    Spacer()
                    Text(L10n.metricPlaceholder())
                        .font(Constants.fontPlaceholder)
                        .foregroundColor(AssetColor.secondaryText)
                    Spacer()
                }


            }
        }
        .sheet(isPresented: $showSheet) {
            switch self.viewModel.activeSheet {
            case .addMetrics:
                GalleryView(allowDismissed: $allowDismissed)
                    .interactiveDismiss(canDismissSheet: $allowDismissed)
                    .environmentObject(viewModel)
            case .info:
                InfoView()
            case .editMetric(let metric):
                EditMetricView(allowDismissed: $allowDismissed, viewModel: MetricViewModel(metric: metric))
                    .interactiveDismiss(canDismissSheet: .constant(false))
                    .environmentObject(viewModel)
            case .none:
                EmptyView()
            }
        }
        .onAppear {
            viewModel.updateMetrics()
        }

    }

    func showSheet(activeSheet: MainViewModel.ActiveSheet) {
        self.viewModel.activeSheet = activeSheet
        self.showSheet.toggle()
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = MainViewModel()
        vm.metrics = Metrics(
            dictionaryLiteral: (UUID(),
                                Metric(id: UUID(), title: "Api Service", measure: "USD", type: .json))
        )
        return MainView(viewModel: vm)
            .preferredColorScheme(.dark)
    }
}
#endif
