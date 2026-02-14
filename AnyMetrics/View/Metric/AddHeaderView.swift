import SwiftUI

fileprivate enum Constants {
    static let font = Font.system(size: 17, weight: .semibold, design: .default)
    static let imageArrow = Image(systemName: "arrow.right")
    static let spacing: CGFloat = 0
    static let buttonInset = EdgeInsets(top: 20, leading: -20, bottom: 0, trailing: -20)
    static let formInset = EdgeInsets(top: -20, leading: 0, bottom: 0, trailing: 0)
    static let buttonCorner: CGFloat = 50
    static let opacityDisable: CGFloat = 0.4
    static let opacityEnable: CGFloat = 1.0
}

struct AddHeaderView: View {

    var action: (String, String) -> Void

    @State 
    var headerName: String = ""
    @State 
    var headerValue: String = ""
    @State 
    var showHeaderPicker: Bool = false
    @Environment(\.presentationMode) 
    var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField(AnyMetricsStrings.Httpheaders.enterName, text: $headerName)
                    }
                } footer: {
                    HStack {
                        NavigationLink {
                            SearchPickerView(
                                title: AnyMetricsStrings.Httpheaders.Select.title,
                                items: HTTP_HEADERS) { selectHeader in
                                self.headerName = selectHeader
                            }
                        } label: {

                            Text(AnyMetricsStrings.Httpheaders.selectFromList)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            Constants.imageArrow
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        }
                    }
                }
                Section {
                    HStack {
                        TextField(AnyMetricsStrings.Httpheaders.enterValue, text: $headerValue)
                    }
                } footer: {
                    VStack {

                        VStack {
                            if let examples = HTTP_HEADER_EXAMPLE[self.headerName] {
                                NavigationLink {
                                    SearchPickerView(title: AnyMetricsStrings.Httpheaders.Select.valueTitle, items: examples) { selectedValue in
                                        self.headerValue = selectedValue
                                    }
                                } label: {
                                    Text(AnyMetricsStrings.Httpheaders.selectValuesFromList)
                                        .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                    Constants.imageArrow
                                        .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                    Spacer()
                                }
                                Divider()
                            }

                            Text(AnyMetricsStrings.Httpheaders.valueInformation)
                                .frame(maxHeight: .infinity)
                        }
                        HStack(alignment: .center, spacing: Constants.spacing, content: {
                            Button(action: {
                                action(headerName, headerValue)
                                presentationMode.wrappedValue.dismiss()
                            }, label: {
                                Spacer()
                                Text(AnyMetricsStrings.Httpheaders.Add.button)
                                    .font(Constants.font)
                                    .padding()
                                Spacer()
                            })
                                .frame(maxWidth: .infinity)
                                .foregroundColor(AnyMetricsAsset.Assets.addMetricTint.swiftUIColor)
                                .background(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                .cornerRadius(Constants.buttonCorner)
                                .disabled(headerName.isEmpty || headerValue.isEmpty)
                                .opacity(opacityButton())
                        })
                        .padding(Constants.buttonInset)
                    }

                }
            }
            .padding(Constants.formInset)
            .navigationTitle(AnyMetricsStrings.Httpheaders.Add.title)
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(PlainListStyle())
        }
    }

    func opacityButton() -> CGFloat {
        return (headerName.isEmpty || headerValue.isEmpty) ? Constants.opacityDisable : Constants.opacityEnable
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
