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
            mainButtonTitle: R.string.localizable.addmetricAdd(),
            viewModel: viewModel,
            action: { metric in
                mainViewModel.addMetric(metric: metric)
                presentationMode.wrappedValue.dismiss()
        })
        .navigationTitle(R.string.localizable.addmetricNewTitle())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            allowDismissed = false
        }
        .onDisappear {
            allowDismissed = true
        }
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
