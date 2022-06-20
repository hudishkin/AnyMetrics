//
//  MainView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import SwiftyJSON

fileprivate enum Constants {
    static let fontTitle: Font = Font.system(size: 19, weight: .heavy, design: .default)
    static let fontPlaceholder: Font = Font.system(size: 16, weight: .regular, design: .default)
    static let padding: CGFloat = 10
    static let titleInset = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    static let infoInset = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    static let spacing: CGFloat = 10
    static let size: CGFloat = (UIScreen.main.bounds.width / 2) - (Self.spacing * 2)
    static let heightPlaceholder: CGFloat = (UIScreen.main.bounds.height) - (Self.spacing * 2)
    static let zIndexTitle: CGFloat = 999
    static let titleCorner: CGFloat = 8
    static let topPadding: CGFloat = 58
    static let bottomPadding: CGFloat = 58
    static let scrollViewInset = EdgeInsets(top: 0, leading: Constants.padding, bottom: 0, trailing: Constants.padding)
    static let addButtonPadding: CGFloat = 14
    static let addButtonSize: CGFloat = 62
    static let addButtonCorner: CGFloat = Self.addButtonSize / 2
}

struct MainView: View {

    @ObservedObject var viewModel: MainViewModel
    @State var showAddMenu = false
    @State var allowDismissed = true
    @State var showActionMenu = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Header
                Button {
                    debugPrint("Header")
                } label: {
                    Text(R.string.localizable.appName())
                        .font(Constants.fontTitle)
                        .foregroundColor(R.color.baseText.color)
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
                self.showAddMenu = true
                ImpactHelper.impactButton()
            } label: {
                R.image.plus.image
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(R.color.baseText.color)
                    .padding(Constants.addButtonPadding)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(Constants.addButtonCorner)
            .frame(width: Constants.addButtonSize, height: Constants.addButtonSize)

            if viewModel.metrics.isEmpty {

                VStack {
                    Spacer()
                    Text(R.string.localizable.metricPlaceholder())
                        .font(Constants.fontPlaceholder)
                        .foregroundColor(R.color.secondaryText.color)
                    Spacer()
                }


            }
        }
        .sheet(isPresented: $showAddMenu) {
            GalleryView(allowDismissed: $allowDismissed)
                .interactiveDismiss(canDismissSheet: $allowDismissed)
                .environmentObject(viewModel)
        }
        .onAppear {
            viewModel.updateMetrics()
        }

    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = MainViewModel()
        vm.metrics = Metrics(
            dictionaryLiteral: (UUID().uuidString,
                                Metric(id: UUID(), title: "Api Service", paramName: "USD", type: .json))
        )
        return MainView(viewModel: vm)
            .preferredColorScheme(.dark)
    }
}
#endif
