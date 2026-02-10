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

struct MetricView: View {
    
    var metric: Metric
    @State var scale = Constants.animationScaleBegin
    @State var opacity = Constants.animationOpacityBegin
    @State var showActionMenu = false
    @State var showConfirmationDelete = false

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
                title: Text(L10n.metricActionsTitle(metric.title)),
                message: nil,
                buttons:
                    [
                        .default(
                            Text(L10n.metricActionsUpdateValue())) {
                            refreshMetric?(metric.id)
                        },
                        .default(
                            Text(L10n.metricActionsEdit())) {
                            editMetric?(metric)
                        },
                        .destructive(
                            Text(L10n.metricActionsDelete())) {
                                showConfirmationDelete = true

                        },
                        .cancel()
                    ]
            )
        })
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
            L10n.metricActionsSure(),
            isPresented: $showConfirmationDelete) {
                Button(L10n.metricActionsConfirmDelete(), role: .destructive) {
                    deletehMetric?(metric.id)
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


