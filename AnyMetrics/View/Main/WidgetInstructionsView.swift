import SwiftUI

fileprivate enum Constants {
    static let contentSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 28
    static let stepSpacing: CGFloat = 18
    static let stepIconSize: CGFloat = 18
    static let stepIconWidth: CGFloat = 28
    static let buttonCorner: CGFloat = 30
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 28
    static let bottomPadding: CGFloat = 24
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor

    static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
    static let fontStep = Font.system(size: 17, weight: .medium, design: .default)
    static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
}

struct WidgetInstructionsView: View {

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let text: String
    }

    let metricTitle: String
    let onDismiss: () -> Void

    @State
    private var sheetHeight: CGFloat = 360

    @State
    private var dontShowAgain = false

    private var steps: [Step] {
        [
            Step(id: 1, icon: "hand.tap", text: AnyMetricsStrings.WidgetGuide.step1),
            Step(id: 2, icon: "plus.app", text: AnyMetricsStrings.WidgetGuide.step2),
            Step(id: 3, icon: "magnifyingglass", text: AnyMetricsStrings.WidgetGuide.step3),
            Step(id: 4, icon: "square.grid.2x2", text: AnyMetricsStrings.WidgetGuide.step4)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                Text(AnyMetricsStrings.WidgetGuide.title)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)

                Text(AnyMetricsStrings.WidgetGuide.subtitle(metricTitle))
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Constants.stepSpacing) {
                ForEach(steps) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Image(systemName: step.icon)
                            .font(.system(size: Constants.stepIconSize, weight: .medium))
                            .foregroundColor(Constants.secondaryColor)
                            .frame(width: Constants.stepIconWidth, alignment: .center)

                        Text(step.text)
                            .font(Constants.fontStep)
                            .foregroundColor(Constants.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(spacing: 16) {
                Toggle(isOn: $dontShowAgain) {
                    Text(AnyMetricsStrings.WidgetGuide.dontShowAgain)
                        .font(Constants.fontSubtitle)
                        .foregroundColor(Constants.secondaryColor)
                }

                Button {
                    ImpactHelper.impactButton()
                    if dontShowAgain {
                        AppSettings.hideWidgetInstructions = true
                    }
                    onDismiss()
                } label: {
                    Text(AnyMetricsStrings.WidgetGuide.done)
                        .font(Constants.fontButton)
                        .foregroundColor(Constants.textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Constants.buttonBackground)
                .cornerRadius(Constants.buttonCorner)
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .padding(.bottom, Constants.bottomPadding)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SheetHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            sheetHeight = height
        }
        .modifier(FittedSheetModifier(height: sheetHeight))
    }
}

private struct SheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FittedSheetModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    WidgetInstructionsView(metricTitle: "Server Status", onDismiss: {})
        .preferredColorScheme(.dark)
}
#endif
