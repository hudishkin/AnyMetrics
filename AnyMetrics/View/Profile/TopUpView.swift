import SwiftUI
import AnyMetricsShared

struct TopUpView: View {
    let balance: Int

    var body: some View {
        Text(MetricCountLabel.text(balance))
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(AnyMetricsStrings.Profile.topUp)
            .navigationBarTitleDisplayMode(.inline)
    }
}
