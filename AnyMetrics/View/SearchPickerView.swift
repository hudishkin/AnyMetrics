//
//  SearchPickerView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//

import SwiftUI

fileprivate enum Constants {
    static let font = Font.system(size: 16, weight: .semibold, design: .default)
    static let itemInset = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
}

/// Call in NavigationView for searchable
///
struct SearchPickerView: View {

    let items: [String]
    let action: (String) -> Void

    @State var searchText: String = ""
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var searchResults: [String] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.contains(searchText) }
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
                        .padding(Constants.itemInset)
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
struct SearchPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SearchPickerView(items: HTTP_HEADERS, action: { _ in
            })
            .preferredColorScheme(.light)
        }
    }
}
#endif
