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
    @State
    var showOnboarding = !AppSettings.hasCompletedOnboarding
    @State
    var widgetInstructionsMetric: Metric?
    @State
    var exportMetric: Metric?
    @State
    var exportFileURL: URL?
    @State
    var exportErrorMessage: String?
#if DEBUG
    @State
    var showDevMenu = false
#endif

    let columns = Constants.collumns

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Header
                HStack(spacing: 8) {
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

#if DEBUG
                    Button {
                        showDevMenu = true
                    } label: {
                        Text("</>")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            .padding(Constants.titleInset)
                            .background(.ultraThinMaterial)
                            .cornerRadius(Constants.titleCorner)
                    }
#endif
                }
                .padding(Constants.padding)
                .zIndex(Constants.zIndexTitle)

                // MARK: - Content
                ScrollView {
                    Spacer(minLength: Constants.topPadding)
                    LazyVGrid(columns: columns, spacing: Constants.spacing) {
                        ForEach(viewState.state.metrics.values.sorted(by: { $0.created > $1.created })) { metric in
                            MetricView(
                                metric: metric,
                                refreshMetric: { uuid in
                                    viewState.trigger(.refreshMetric(uuid))
                                },
                                deletehMetric: { uuid in
                                    viewState.trigger(.removeMetric(uuid))
                                },
                                editMetric: { metric in
                                    sheetType = .editMetric(metric)
                                },
                                exportMetric: { metric in
                                    exportMetric = metric
                                }
                            )
                            .frame(width: Constants.size, height: Constants.size)
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
        }
        .sheet(item: $sheetType, onDismiss: {
            allowDismissed = true
        }) { type in
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
                            viewState.trigger(.addMetricAndRefresh(updatedMetric))
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
        .sheet(item: $widgetInstructionsMetric) { metric in
            WidgetInstructionsView(metricTitle: metric.title) {
                widgetInstructionsMetric = nil
            }
        }
        .sheet(item: $exportMetric, onDismiss: {
            presentExportShareSheetIfNeeded()
        }) { metric in
            MetricExportOptionsView(metric: metric) { fileURL in
                exportFileURL = fileURL
                exportMetric = nil
            }
        }
        .alert(AnyMetricsStrings.Common.error, isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button(AnyMetricsStrings.Common.ok, role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                AppSettings.hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
#if DEBUG
        .sheet(isPresented: $showDevMenu) {
            DevMenuView {
                showOnboarding = true
            }
        }
#endif
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .showWidgetInstructions(let metric):
                widgetInstructionsMetric = metric
            case .error:
                break
            }
        }
        .onAppear {
            viewState.trigger(.onAppear)
        }

    }

    private func presentExportShareSheetIfNeeded() {
        guard let fileURL = exportFileURL else { return }
        MetricSharePresenter.present(fileURL: fileURL) { presented in
            cleanupExportFile()
            if !presented {
                exportErrorMessage = AnyMetricsStrings.Metric.Export.failed
            }
        }
    }

    private func cleanupExportFile() {
        if let url = exportFileURL {
            try? FileManager.default.removeItem(at: url)
            exportFileURL = nil
        }
    }
}

#Preview {
    MainView()
}
