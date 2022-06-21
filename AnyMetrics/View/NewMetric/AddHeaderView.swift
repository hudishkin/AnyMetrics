//
//  AddHeaderView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//

import SwiftUI

fileprivate enum Constants {
    static let font = Font.system(size: 17, weight: .semibold, design: .default)
    static let imageArrow = Image(systemName: "arrow.right")
    static let spacing: CGFloat = 0
    static let buttonInset = EdgeInsets(top: 20, leading: -20, bottom: 0, trailing: -20)
    static let formInset = EdgeInsets(top: -20, leading: 0, bottom: 0, trailing: 0)
    static let buttonCorner: CGFloat = 50
}

struct AddHeaderView: View {

    var action: (String, String) -> Void

    @State var headerName: String = ""
    @State var headerValue: String = ""
    @State var showHeaderPicker: Bool = false
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField(R.string.localizable.httpheadersEnterName(), text: $headerName)
                    }
                } footer: {
                    HStack {
                        NavigationLink {
                            SearchPickerView(items: HTTP_HEADERS) { selectHeader in
                                self.headerName = selectHeader
                            }
                        } label: {

                            Text(R.string.localizable.httpheadersSelectFromList())
                                .foregroundColor(R.color.baseText.color)
                            Constants.imageArrow
                                .foregroundColor(R.color.baseText.color)
                        }
                    }
                }
                Section {
                    HStack {
                        TextField(R.string.localizable.httpheadersEnterValue(), text: $headerValue)
                    }
                } footer: {
                    VStack {

                        VStack {
                            if let examples = HTTP_HEADER_EXAMPLE[headerName] {
                                HStack {
                                    NavigationLink {
                                        SearchPickerView(items: examples) { selectedValue in
                                            self.headerValue = selectedValue
                                        }
                                    } label: {
                                        Text(R.string.localizable.httpheadersSelectValuesFromList())
                                            .foregroundColor(R.color.baseText.color)
                                        Constants.imageArrow
                                            .foregroundColor(R.color.baseText.color)
                                        Spacer()
                                    }

                                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                            }
                            Text(R.string.localizable.httpheadersValueInformation())
                            Spacer()
                        }

                        HStack(alignment: .center, spacing: Constants.spacing, content: {
                            Button(action: {
                                action(headerName, headerValue)
                                presentationMode.wrappedValue.dismiss()
                            }, label: {
                                Spacer()
                                Text(R.string.localizable.httpheadersAddButton())
                                    .font(Constants.font)
                                    .padding()
                                Spacer()
                            })
                                .frame(maxWidth: .infinity)
                                .foregroundColor(R.color.addMetricTint.color)
                                .background(R.color.baseText.color)
                                .cornerRadius(Constants.buttonCorner)
                                .disabled(headerName.isEmpty || headerValue.isEmpty)
                        })
                        .padding(Constants.buttonInset)
                    }

                }
            }
            .padding(Constants.formInset)
            .navigationTitle(R.string.localizable.httpheadersAddTitle())
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(PlainListStyle())
        }
    }
}


#if DEBUG
struct AddHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        AddHeaderView(action: { _, _ in})
            .preferredColorScheme(.light)
    }
}
#endif
