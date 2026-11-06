//
//  MetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import UIKit
import AnyMetricsShared

fileprivate enum Constants {

    static let animationInit = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let timeRange = 0.0...0.12
    static let animationScaleEnd: CGFloat = 1.0
    static let animationScaleBegin: CGFloat = 0.78
    static let animationOpacityBegin: CGFloat = 0.0
    static let animationOpacityEnd: CGFloat = 1.0
}

// MARK: - Share

enum MetricSharePresenter {
    private static let maxAttempts = 10
    private static let retryDelay: TimeInterval = 0.2

    enum Result {
        case dismissed(completed: Bool, activity: String?)
        case failed
    }

    static func present(fileURL: URL, completion: ((Result) -> Void)? = nil) {
        present(items: [fileURL], completion: completion)
    }

    static func present(items: [Any], completion: ((Result) -> Void)? = nil) {
        present(items: items, attempt: 0, completion: completion)
    }

    private static func present(items: [Any], attempt: Int, completion: ((Result) -> Void)?) {
        let missingLocalFile = items.contains { item in
            guard let url = item as? URL, url.isFileURL else { return false }
            return !FileManager.default.fileExists(atPath: url.path)
        }
        if missingLocalFile {
            completion?(.failed)
            return
        }

        guard let presenter = topViewController() else {
            retryOrFail(items: items, attempt: attempt, completion: completion)
            return
        }

        if presenter.presentedViewController != nil
            || presenter.isBeingDismissed
            || presenter.isBeingPresented {
            retryOrFail(items: items, attempt: attempt, completion: completion)
            return
        }

        let activity = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        final class PresentationState {
            var finished = false
        }
        let state = PresentationState()

        activity.completionWithItemsHandler = { activityType, completed, _, _ in
            DispatchQueue.main.async {
                guard !state.finished else { return }
                state.finished = true
                completion?(.dismissed(completed: completed, activity: activityType?.rawValue))
            }
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activity, animated: true)

        // UIKit can silently refuse present during transitions; detect and retry.
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            guard !state.finished else { return }
            if activity.presentingViewController == nil {
                retryOrFail(items: items, attempt: attempt, completion: completion)
            }
        }
    }

    private static func retryOrFail(
        items: [Any],
        attempt: Int,
        completion: ((Result) -> Void)?
    ) {
        guard attempt + 1 < maxAttempts else {
            completion?(.failed)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            present(items: items, attempt: attempt + 1, completion: completion)
        }
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

struct MetricView: View {

    var metric: Metric
    /// Новая метрика появляется сразу. При старте дашборда карточки чуть разъезжаются по времени.
    var appearsImmediately = false
    @State var scale = Constants.animationScaleBegin
    @State var opacity = Constants.animationOpacityBegin
    @State var showActionMenu = false
    @State var showConfirmationDelete = false
    @State private var exportAfterDeletePrompt = false
    @State private var pendingAction: PendingAction?

    private enum PendingAction {
        case editRequest, editTheme, duplicate, share, export, delete
    }

    var refreshMetric: ((UUID) -> Void)?
    var deletehMetric: ((UUID) -> Void)?
    var editRequest: ((Metric) -> Void)?
    var editTheme: ((Metric) -> Void)?
    var duplicateMetric: ((Metric) -> Void)?
    var shareMetric: ((Metric) -> Void)?
    var exportMetric: ((Metric) -> Void)?
    var onOverlayChange: ((Bool) -> Void)?

    var body: some View {
        Button {
            showActionMenu = true
        } label: {
            MetricContentView(metric: metric)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showActionMenu, onDismiss: performPendingAction) {
            MetricActionsMenuView(
                onRefresh: {
                    showActionMenu = false
                    refreshMetric?(metric.id)
                },
                onEditRequest: { queueAction(.editRequest) },
                onEditTheme: { queueAction(.editTheme) },
                onDuplicate: { queueAction(.duplicate) },
                onExport: { queueAction(.export) },
                onShare: { queueAction(.share) },
                onDelete: { queueAction(.delete) }
            )
        }
        .onChange(of: showActionMenu) { presented in
            if presented {
                onOverlayChange?(true)
            }
        }
        .alert(
            AnyMetricsStrings.Metric.Actions.sure,
            isPresented: $showConfirmationDelete
        ) {
            Button(AnyMetricsStrings.Metric.Actions.export) {
                exportAfterDeletePrompt = true
            }
            Button(AnyMetricsStrings.Metric.Actions.confirmDelete, role: .destructive) {
                deletehMetric?(metric.id)
            }
            Button(AnyMetricsStrings.Common.close, role: .cancel) {}
        } message: {
            Text(AnyMetricsStrings.Metric.Actions.deleteMessage)
        }
        .onChange(of: showConfirmationDelete) { presented in
            if !presented {
                let shouldExport = exportAfterDeletePrompt
                exportAfterDeletePrompt = false
                onOverlayChange?(false)
                if shouldExport {
                    DispatchQueue.main.async {
                        exportMetric?(metric)
                    }
                }
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            let delay = appearsImmediately ? 0 : Double.random(in: Constants.timeRange)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(Constants.animationInit) {
                    scale = Constants.animationScaleEnd
                    opacity = Constants.animationOpacityEnd
                }
            }
        }
    }

    private func queueAction(_ action: PendingAction) {
        pendingAction = action
        showActionMenu = false
    }

    private func performPendingAction() {
        switch pendingAction {
        case .editRequest:
            editRequest?(metric)
        case .editTheme:
            editTheme?(metric)
        case .duplicate:
            duplicateMetric?(metric)
        case .share:
            shareMetric?(metric)
        case .export:
            exportMetric?(metric)
        case .delete:
            showConfirmationDelete = true
        case nil:
            break
        }
        pendingAction = nil
        onOverlayChange?(showActionMenu || showConfirmationDelete)
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
