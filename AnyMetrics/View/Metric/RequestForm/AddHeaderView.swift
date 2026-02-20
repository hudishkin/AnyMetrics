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

    enum Mode {
        case add
        case edit
    }

    let mode: Mode
    var action: (String, String) -> Void
    var onDelete: (() -> Void)?

    @State
    var headerName: String
    @State
    var headerValue: String
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>

    init(
        mode: Mode = .add,
        headerName: String = "",
        headerValue: String = "",
        onDelete: (() -> Void)? = nil,
        action: @escaping (String, String) -> Void
    ) {
        self.mode = mode
        self.action = action
        self.onDelete = onDelete
        _headerName = State(initialValue: headerName)
        _headerValue = State(initialValue: headerValue)
    }

    private var isEditing: Bool { mode == .edit }

    private var navigationTitle: String {
        isEditing
            ? AnyMetricsStrings.Httpheaders.Edit.title
            : AnyMetricsStrings.Httpheaders.Add.title
    }

    private var actionButtonTitle: String {
        isEditing
            ? AnyMetricsStrings.Httpheaders.Edit.button
            : AnyMetricsStrings.Httpheaders.Add.button
    }

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
                                Text(actionButtonTitle)
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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    if isEditing, let onDelete {
                        Button {
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text(AnyMetricsStrings.Httpheaders.Actions.delete)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
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
        Group {
            AddHeaderView(mode: .add) { _, _ in }
                .preferredColorScheme(.light)
                .previewDisplayName("Add Mode")
            AddHeaderView(mode: .edit, headerName: "Content-Type", headerValue: "application/json") { _, _ in }
                .preferredColorScheme(.light)
                .previewDisplayName("Edit Mode")
        }
    }
}
#endif
