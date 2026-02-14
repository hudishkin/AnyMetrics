//
//  MetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import AnyMetricsShared

fileprivate enum Constants {

    static let animationInit = Animation.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.4)
    static let timeRange = 0.1...0.7
    static let animationScaleEnd: CGFloat = 1.0
    static let animationScaleBegin: CGFloat = 0.4
    static let animationOpacityBegin: CGFloat = 0.0
    static let animationOpacityEnd: CGFloat = 1.0
}

// MARK: - Share Sheet Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let completion: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MetricView: View {
    
    var metric: Metric
    @State var scale = Constants.animationScaleBegin
    @State var opacity = Constants.animationOpacityBegin
    @State var showActionMenu = false
    @State var showConfirmationDelete = false
    @State var exportFileURL: URL?
    @State var showShareSheet = false

    var refreshMetric: ((UUID) -> Void)?
    var deletehMetric: ((UUID) -> Void)?
    var editMetric: ((Metric) -> Void)?

    var body: some View {
        Button {
            showActionMenu = true
        } label: {
            MetricContentView(metric: metric)
        }
        .actionSheet(isPresented: $showActionMenu, content: { [metric] in
            ActionSheet(
                title: Text(AnyMetricsStrings.Metric.Actions.title(metric.title)),
                message: nil,
                buttons:
                    [
                        .default(
                            Text(AnyMetricsStrings.Metric.Actions.updateValue)) {
                            refreshMetric?(metric.id)
                        },
                        .default(
                            Text(AnyMetricsStrings.Metric.Actions.edit)) {
                            editMetric?(metric)
                        },
                        .default(
                            Text(AnyMetricsStrings.Metric.Actions.export)) {
                            exportMetricAsJSON(metric)
                        },
                        .destructive(
                            Text(AnyMetricsStrings.Metric.Actions.delete)) {
                                showConfirmationDelete = true

                        },
                        .cancel()
                    ]
            )
        })
        .sheet(isPresented: $showShareSheet, onDismiss: {
            cleanupExportFile()
        }) {
            if let fileURL = exportFileURL {
                ActivityViewController(
                    activityItems: [fileURL],
                    applicationActivities: nil,
                    completion: {
                        showShareSheet = false
                    }
                )
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: getAnimationTimeInterval()) {
                withAnimation(Constants.animationInit) {
                    scale = Constants.animationScaleEnd
                    opacity = Constants.animationOpacityEnd
                }
            }
        }.confirmationDialog(
            AnyMetricsStrings.Metric.Actions.sure,
            isPresented: $showConfirmationDelete) {
                Button(AnyMetricsStrings.Metric.Actions.confirmDelete, role: .destructive) {
                    deletehMetric?(metric.id)
                }
            }
    }

    private func getAnimationTimeInterval() -> DispatchTime {
        return DispatchTime.now() + Double.random(in: Constants.timeRange)
    }

    private func exportMetricAsJSON(_ metric: Metric) {
        let exportData = MetricItemImportData.exportData(for: metric)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(exportData) else { return }

        let fileName = metric.title
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).json")

        try? jsonData.write(to: tempURL)
        exportFileURL = tempURL
        showShareSheet = true
    }

    private func cleanupExportFile() {
        if let url = exportFileURL {
            try? FileManager.default.removeItem(at: url)
            exportFileURL = nil
        }
    }
}

#if DEBUG
struct MetricView_Previews: PreviewProvider {
    static var previews: some View {
        MetricView(metric: Mocks.metricCheck).environment(\.sizeCategory, .medium).previewLayout(.sizeThatFits).frame(width: 200, height: 200, alignment: .leading)

        MetricView(metric: Mocks.metricJson).environment(\.sizeCategory, .medium).previewLayout(.sizeThatFits).frame(width: 200, height: 200, alignment: .leading)

        MetricView(metric: Mocks.metricCheckWithError).environment(\.sizeCategory, .medium).previewLayout(.sizeThatFits).frame(width: 200, height: 200, alignment: .leading)
    }
}
#endif


