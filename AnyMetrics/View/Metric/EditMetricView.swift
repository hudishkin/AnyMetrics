//
//  EditMetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 28.06.2022.
//

import SwiftUI


struct EditMetricView: View {

    @Binding var allowDismissed: Bool
    @StateObject var viewModel: MetricViewModel
    @EnvironmentObject var mainViewModel: MainViewModel
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            MetricFormView(
                allowDismissed: $allowDismissed,
                mainButtonTitle: R.string.localizable.commonSave(),
                viewModel: viewModel,
                action: { metric in
                    mainViewModel.addMetric(metric: metric)
                    mainViewModel.updateMetric(id: metric.id)
                    presentationMode.wrappedValue.dismiss()
            })
            .navigationTitle(R.string.localizable.metricActionsEdit())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(R.string.localizable.commonClose()) {
                    presentationMode.wrappedValue.dismiss()
                }
            }

        }
    }
}


#if DEBUG

struct EditMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditMetricView(allowDismissed: .constant(true), viewModel: MetricViewModel())
                .environmentObject(MainViewModel())
                .preferredColorScheme(.dark)
        }
    }
}
#endif
