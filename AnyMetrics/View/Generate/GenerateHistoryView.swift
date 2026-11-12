import SwiftUI

struct GenerateHistoryView: View {

    var body: some View {
        Text(AnyMetricsStrings.Generate.History.empty)
            .font(GenerateMetricView.Constants.examplesFont)
            .foregroundColor(GenerateMetricView.Constants.secondaryColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, GenerateMetricView.Constants.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(AnyMetricsStrings.Generate.history)
            .navigationBarTitleDisplayMode(.inline)
    }
}
