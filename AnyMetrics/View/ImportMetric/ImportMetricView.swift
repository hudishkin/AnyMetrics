import SwiftUI
import VVSI
import AnyMetricsShared

struct ImportMetricView: View {

    enum Constants {
        static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
        static let mainButtonPadding: CGFloat = -16
        static let mainButtonCorner: CGFloat = 40
        static let mainButtonHeight: CGFloat = 52
        static let buttonBackground = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let buttonTextColor = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
    }

    enum AlertType: Identifiable {
        var id: String { "\(self)" }
        case error(String)
    }

    @StateObject
    private var viewState = ViewState(.init(), Interactor())

    @State
    private var alertType: AlertType? = nil

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var onImported: ((Metric) -> Void)?

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - JSON TextEditor
            TextEditor(text: Binding(
                get: { viewState.state.jsonText },
                set: { viewState.trigger(.setJsonText($0)) }
            ))
            .font(.system(.body, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .overlay(placeholderOverlay, alignment: .topLeading)
            .padding(.horizontal)
            .padding(.top, 8)

            // MARK: - Validation Info
            validationView
                .padding(.horizontal)
                .padding(.vertical, 8)

            // MARK: - Import Button
            Button {
                viewState.trigger(.importMetric)
            } label: {
                Text(AnyMetricsStrings.Import.Button.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(AnyMetricsAsset.Assets.addMetricTint.swiftUIColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                    .cornerRadius(40)
            }
            .disabled(!viewState.state.validation.isValid)
            .opacity(viewState.state.validation.isValid ? 1.0 : 0.4)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .onAppear {
            viewState.trigger(.onAppear)
        }
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .showError(let error):
                alertType = .error(error)
            case .imported:
                if let metric = viewState.state.validation.metric {
                    onImported?(metric)
                }
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
    }

    // MARK: - Subviews

    @ViewBuilder
    private var placeholderOverlay: some View {
        if viewState.state.jsonText.isEmpty {
            Text(AnyMetricsStrings.Import.placeholder)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var validationView: some View {
        switch viewState.state.validation {
        case .idle:
            EmptyView()

        case .valid(let metric):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(AnyMetricsStrings.Import.Validation.valid)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.green)
                }

                Group {
                    infoRow(label: AnyMetricsStrings.Import.Info.title, value: metric.title)
                    infoRow(label: AnyMetricsStrings.Import.Info.measure, value: metric.measure)
                    infoRow(label: AnyMetricsStrings.Import.Info.type, value: metric.type.rawValue)
                    if let url = metric.request?.url.absoluteString {
                        infoRow(label: "URL", value: url)
                    }
                }
                .font(.caption)
                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)

                if viewState.state.duplicateIdFound {
                    Divider()

                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(AnyMetricsStrings.Import.Validation.duplicateId)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)

        case .invalid(let message):
            HStack(alignment: .center) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Text(value)
                .lineLimit(1)
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        ImportMetricView()
            .navigationTitle(AnyMetricsStrings.Import.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
