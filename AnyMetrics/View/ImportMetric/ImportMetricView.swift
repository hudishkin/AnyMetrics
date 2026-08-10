import SwiftUI
import UniformTypeIdentifiers
import VVSI
import AnyMetricsShared

struct ImportMetricView: View {

    enum Constants {
        static let contentSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let cardCorner: CGFloat = 18
        static let buttonCorner: CGFloat = 30
        static let editorCorner: CGFloat = 18

        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let primaryButtonBackground = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let primaryButtonText = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        static let successColor = Color.green
        static let warningColor = Color.orange
        static let errorColor = AnyMetricsAsset.Assets.red.swiftUIColor

        static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
        static let fontSecondaryButton = Font.system(size: 16, weight: .medium, design: .default)
        static let fontStatus = Font.system(size: 15, weight: .medium, design: .default)
        static let fontInfo = Font.system(size: 13, weight: .regular, design: .default)
        static let fontCaption = Font.system(size: 12, weight: .regular, design: .default)
        static let fontEditor = Font.system(.body, design: .monospaced)
    }

    enum AlertType: Identifiable {
        var id: String { "\(self)" }
        case error(String)
    }

    @StateObject
    private var viewState = ViewState(.init(), Interactor())

    @State
    private var alertType: AlertType? = nil
    @State
    private var showFileImporter = false
    @FocusState
    private var isEditorFocused: Bool

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var onImported: ((Metric) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: Binding(
                get: { viewState.state.jsonText },
                set: { viewState.trigger(.setJsonText($0)) }
            ))
            .font(Constants.fontEditor)
            .foregroundColor(Constants.textColor)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .focused($isEditorFocused)
            .padding(10)
            .modifier(ImportEditorBackgroundModifier())
            .background(Constants.cardBackground)
            .cornerRadius(Constants.editorCorner)
            .overlay(placeholderOverlay, alignment: .topLeading)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)

            validationView
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, Constants.sectionSpacing)

            Button {
                isEditorFocused = false
                showFileImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                    Text(AnyMetricsStrings.Import.chooseFile)
                        .font(Constants.fontSecondaryButton)
                }
                .foregroundColor(Constants.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Constants.buttonBackground)
                .cornerRadius(Constants.buttonCorner)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.sectionSpacing)
            .padding(.bottom, 8)

            Button {
                isEditorFocused = false
                ImpactHelper.impactButton()
                viewState.trigger(.importMetric)
            } label: {
                Text(AnyMetricsStrings.Import.Button.title)
                    .font(Constants.fontButton)
                    .foregroundColor(Constants.primaryButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.primaryButtonBackground)
                    .cornerRadius(Constants.buttonCorner)
            }
            .disabled(!viewState.state.validation.isValid)
            .opacity(viewState.state.validation.isValid ? 1.0 : 0.4)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isEditorFocused = false
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel(AnyMetricsStrings.Common.ok)
            }
        }
        .onAppear {
            viewState.trigger(.onAppear)
        }
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .showError(let error):
                alertType = .error(error)
            case .imported(let metric):
                onImported?(metric)
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert(item: $alertType) { item in
            switch item {
            case .error(let error):
                Alert(
                    title: Text(AnyMetricsStrings.Common.error),
                    message: Text(error),
                    dismissButton: .default(Text(AnyMetricsStrings.Common.ok))
                )
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            alertType = .error(AnyMetricsStrings.Import.Error.cannotReadFile)
        case .success(let urls):
            guard let url = urls.first else {
                alertType = .error(AnyMetricsStrings.Import.Error.cannotReadFile)
                return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    alertType = .error(AnyMetricsStrings.Import.Error.cannotReadFile)
                    return
                }
                viewState.trigger(.setJsonText(text))
            } catch {
                alertType = .error(AnyMetricsStrings.Import.Error.cannotReadFile)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var placeholderOverlay: some View {
        if viewState.state.jsonText.isEmpty {
            Text(AnyMetricsStrings.Import.placeholder)
                .font(Constants.fontEditor)
                .foregroundColor(Constants.secondaryColor)
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var validationView: some View {
        switch viewState.state.validation {
        case .idle:
            EmptyView()

        case .valid(let metric):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Constants.successColor)
                    Text(AnyMetricsStrings.Import.Validation.valid)
                        .font(Constants.fontStatus)
                        .foregroundColor(Constants.successColor)
                }

                Group {
                    infoRow(label: AnyMetricsStrings.Import.Info.title, value: metric.title)
                    infoRow(label: AnyMetricsStrings.Import.Info.measure, value: metric.measure)
                    infoRow(label: AnyMetricsStrings.Import.Info.type, value: metric.type.rawValue)
                    if let url = metric.request?.url.absoluteString {
                        infoRow(label: "URL", value: url)
                    }
                    if metric.widgetAppearance != nil || metric.widgetDesign != nil {
                        infoRow(
                            label: AnyMetricsStrings.Import.Info.widgetStyle,
                            value: AnyMetricsStrings.Import.Info.included
                        )
                    }
                }
                .font(Constants.fontInfo)
                .foregroundColor(Constants.secondaryColor)

                if viewState.state.duplicateIdFound {
                    Divider()
                        .background(Constants.secondaryColor.opacity(0.3))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Constants.warningColor)
                        Text(AnyMetricsStrings.Import.Validation.duplicateId)
                            .font(Constants.fontCaption)
                            .foregroundColor(Constants.warningColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.cardBackground)
            .cornerRadius(Constants.cardCorner)

        case .invalid(let message):
            Text(message)
                .multilineTextAlignment(.center)
                .font(Constants.fontStatus)
                .foregroundColor(Constants.errorColor)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Constants.cardBackground)
                .cornerRadius(Constants.cardCorner)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Text(value)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct ImportEditorBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

#Preview {
    NavigationView {
        ImportMetricView()
            .navigationTitle(AnyMetricsStrings.Import.title)
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
