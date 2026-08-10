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

    static let animationInit = Animation.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.4)
    static let timeRange = 0.1...0.7
    static let animationScaleEnd: CGFloat = 1.0
    static let animationScaleBegin: CGFloat = 0.4
    static let animationOpacityBegin: CGFloat = 0.0
    static let animationOpacityEnd: CGFloat = 1.0
}

// MARK: - Share

enum MetricSharePresenter {
    private static let maxAttempts = 10
    private static let retryDelay: TimeInterval = 0.2

    static func present(fileURL: URL, completion: ((Bool) -> Void)? = nil) {
        present(fileURL: fileURL, attempt: 0, completion: completion)
    }

    private static func present(fileURL: URL, attempt: Int, completion: ((Bool) -> Void)?) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion?(false)
            return
        }

        guard let presenter = topViewController() else {
            retryOrFail(fileURL: fileURL, attempt: attempt, completion: completion)
            return
        }

        if presenter.presentedViewController != nil
            || presenter.isBeingDismissed
            || presenter.isBeingPresented {
            retryOrFail(fileURL: fileURL, attempt: attempt, completion: completion)
            return
        }

        let activity = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        final class PresentationState {
            var finished = false
        }
        let state = PresentationState()

        activity.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                guard !state.finished else { return }
                state.finished = true
                completion?(true)
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
                retryOrFail(fileURL: fileURL, attempt: attempt, completion: completion)
            }
        }
    }

    private static func retryOrFail(
        fileURL: URL,
        attempt: Int,
        completion: ((Bool) -> Void)?
    ) {
        guard attempt + 1 < maxAttempts else {
            completion?(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            present(fileURL: fileURL, attempt: attempt + 1, completion: completion)
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
    @State var scale = Constants.animationScaleBegin
    @State var opacity = Constants.animationOpacityBegin
    @State var showActionMenu = false
    @State var showConfirmationDelete = false

    var refreshMetric: ((UUID) -> Void)?
    var deletehMetric: ((UUID) -> Void)?
    var editMetric: ((Metric) -> Void)?
    var exportMetric: ((Metric) -> Void)?

    var body: some View {
        Button {
            showActionMenu = true
        } label: {
            MetricContentView(metric: metric)
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            AnyMetricsStrings.Metric.Actions.title(metric.title),
            isPresented: $showActionMenu,
            titleVisibility: .visible
        ) {
            Button(AnyMetricsStrings.Metric.Actions.updateValue) {
                refreshMetric?(metric.id)
            }
            Button(AnyMetricsStrings.Metric.Actions.edit) {
                editMetric?(metric)
            }
            Button(AnyMetricsStrings.Metric.Actions.export) {
                // Defer so the actions dialog can finish dismissing first.
                DispatchQueue.main.async {
                    exportMetric?(metric)
                }
            }
            Button(AnyMetricsStrings.Metric.Actions.delete, role: .destructive) {
                // Defer so the actions dialog can finish dismissing first.
                DispatchQueue.main.async {
                    showConfirmationDelete = true
                }
            }
        }
        .confirmationDialog(
            AnyMetricsStrings.Metric.Actions.sure,
            isPresented: $showConfirmationDelete
        ) {
            Button(AnyMetricsStrings.Metric.Actions.confirmDelete, role: .destructive) {
                deletehMetric?(metric.id)
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
        }
    }

    private func getAnimationTimeInterval() -> DispatchTime {
        return DispatchTime.now() + Double.random(in: Constants.timeRange)
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
