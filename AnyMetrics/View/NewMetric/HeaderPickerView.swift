//
//  HeaderPickerView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//

import SwiftUI

fileprivate enum Constants {
    static let font = Font.system(size: 17, weight: .semibold, design: .default)
}

/// Call in NavigationView for searchable
///
struct HeaderPickerView: View {

    var action: (String) -> Void

    @State var searchText: String = ""
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var searchResults: [String] {
        if searchText.isEmpty {
            return HttpHeaders
        } else {
            return HttpHeaders.filter { $0.contains(searchText) }
        }
    }

    var body: some View {
        List(searchResults, id:\.self) { item in
            HStack {
                Button {
                    action(item)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(item)
                        .font(Constants.font)
                        .foregroundColor(R.color.baseText.color)
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle(R.string.localizable.httpheadersSelectTitle())
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always))
    }
}


#if DEBUG
struct HeaderPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HeaderPickerView(action: { _ in
            })
            .preferredColorScheme(.light)
        }
    }
}
#endif
