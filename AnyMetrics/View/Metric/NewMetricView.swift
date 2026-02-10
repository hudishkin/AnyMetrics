//
//  NewMetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//

import SwiftUI

struct NewMetricView: View {
    
    @Binding var allowDismissed: Bool
    var close: () -> Void

    @StateObject var viewModel = MetricViewModel()
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        MetricFormView(
            allowDismissed: $allowDismissed,
            mainButtonTitle: L10n.addmetricButtonAdd(),
            viewModel: viewModel,
            action: { metric in
                mainViewModel.addMetric(metric: metric)
                mainViewModel.updateMetric(id: metric.id)
                close()
        })
        .navigationTitle(L10n.addmetricTitleNew())
        .navigationBarTitleDisplayMode(.inline)
        
    }

}


#if DEBUG

struct NewMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewMetricView(allowDismissed: .constant(true), close: {
                
            })
                .environmentObject(MainViewModel())
                .preferredColorScheme(.dark)
        }
    }
}
#endif
