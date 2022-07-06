//
//  NewMetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//

import SwiftUI

struct NewMetricView: View {
    @Binding var allowDismissed: Bool
    @StateObject var viewModel = MetricViewModel()
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        MetricFormView(
            allowDismissed: $allowDismissed,
            mainButtonTitle: R.string.localizable.addmetricButtonAdd(),
            viewModel: viewModel,
            action: { metric in
                mainViewModel.addMetric(metric: metric)
                mainViewModel.updateMetric(id: metric.id)
                presentationMode.wrappedValue.dismiss()
        })
        .navigationTitle(R.string.localizable.addmetricTitleNew())
        .navigationBarTitleDisplayMode(.inline)
        
    }

}


#if DEBUG

struct NewMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewMetricView(allowDismissed: .constant(true))
                .environmentObject(MainViewModel())
                .preferredColorScheme(.dark)
        }
    }
}
#endif
