import SwiftUI
import SwiftyJSON
import AnyMetricsShared
import VVSI

struct MainView: View {

    enum SheetType: Identifiable {
        var id: String { "\(self)" }
        case addMetrics
        case info
        case editMetric(Metric)
    }

    @StateObject
    var viewState: ViewState<Interactor> = .init(Interactor())
    @State
    var sheetType: SheetType?
    @State
    var allowDismissed = true
    @State
    var showActionMenu = false

    let columns = Constants.collumns

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Header
                Button {
                    sheetType = .info
                } label: {
                    Text(AnyMetricsStrings.appName)
                        .font(Constants.fontTitle)
                        .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
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
                        ForEach(viewState.state.metrics.values.sorted(by: { $0.created > $1.created })) { metric in
                            MetricView(metric: metric, refreshMetric: { uuid in
                                viewState.trigger(.refreshMetric(uuid))
                            }, deletehMetric: { uuid in
                                viewState.trigger(.removeMetric(uuid))
                            }, editMetric: { metric in
                                sheetType = .editMetric(metric)
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
                sheetType = .addMetrics

            } label: {
                AnyMetricsAsset.Assets.plus.swiftUIImage
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                    .padding(Constants.addButtonPadding)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(Constants.addButtonCorner)
            .frame(width: Constants.addButtonSize, height: Constants.addButtonSize)
            .padding()

            if viewState.state.metrics.isEmpty {

                VStack {
                    Spacer()
                    Text(AnyMetricsStrings.Metric.placeholder)
                        .font(Constants.fontPlaceholder)
                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                    Spacer()
                }
            }
        }
        .sheet(item: $sheetType) { type in
            switch type {
            case .addMetrics:
                GalleryView(allowDismissed: $allowDismissed)
                    .interactiveDismiss(canDismissSheet: $allowDismissed)
                    .environmentObject(viewState)
            case .info:
                InfoView()
            case .editMetric(let metric):
                NavigationView {
                    MetricFormView(
                        allowDismissed: $allowDismissed,
                        metric: metric,
                        action: { updatedMetric in
                            viewState.trigger(.addMetric(updatedMetric))
                            sheetType = nil
                        }
                    )
                    .navigationTitle(AnyMetricsStrings.Metric.Actions.edit)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button(AnyMetricsStrings.Common.close) {
                            sheetType = nil
                        }
                    }
                }
                .interactiveDismiss(canDismissSheet: .constant(false))
                .environmentObject(viewState)
            }
        }
        .onAppear {
            viewState.trigger(.onAppear)
        }

    }
}

#Preview {
    MainView()
}
