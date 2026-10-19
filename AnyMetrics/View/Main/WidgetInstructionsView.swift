import SwiftUI

fileprivate enum Constants {
    static let contentSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 28
    static let stepSpacing: CGFloat = 18
    static let stepCardCorner: CGFloat = 28
    static let stepCardHeight: CGFloat = 400
    static let buttonCorner: CGFloat = 30
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 28
    static let bottomPadding: CGFloat = 24
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor

    static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
    static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
}

struct WidgetInstructionsView: View {

    /// Home Screen steps changed in iOS 18 and are still the same in Apple’s iOS 26 guide.
    /// Add a case here when a later system version changes the path.
    enum System {
        /// iOS 16–17: Add button (+) in the upper-left corner.
        case ios16
        /// iOS 18 and later: Edit, then Add Widget.
        case ios18

        static var current: System {
            if #available(iOS 18.0, *) {
                return .ios18
            }
            return .ios16
        }
    }

    private struct Step: Identifiable {
        let id: Int
        let text: String
    }

    let metricTitle: String
    var system: System = .current
    let onDone: (Bool) -> Void

    @State
    private var sheetHeight: CGFloat = 360

    @State
    private var dontShowAgain = false

    @State
    private var stepIndex = 0

    private var steps: [Step] {
        switch system {
        case .ios16:
            return [
                Step(id: 1, text: AnyMetricsStrings.WidgetGuide.Ios16.step1),
                Step(id: 2, text: AnyMetricsStrings.WidgetGuide.Ios16.step2),
                Step(id: 3, text: AnyMetricsStrings.WidgetGuide.Ios16.step3),
                Step(id: 4, text: AnyMetricsStrings.WidgetGuide.Ios16.step4),
                Step(id: 5, text: AnyMetricsStrings.WidgetGuide.Ios16.selectMetric(metricTitle))
            ]
        case .ios18:
            return [
                Step(id: 1, text: AnyMetricsStrings.WidgetGuide.Ios18.step1),
                Step(id: 2, text: AnyMetricsStrings.WidgetGuide.Ios18.step2),
                Step(id: 3, text: AnyMetricsStrings.WidgetGuide.Ios18.step3),
                Step(id: 4, text: AnyMetricsStrings.WidgetGuide.Ios18.step4),
                Step(id: 5, text: AnyMetricsStrings.WidgetGuide.Ios18.selectMetric(metricTitle))
            ]
        }
    }

    private var currentStep: Step {
        steps[min(stepIndex, steps.count - 1)]
    }

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                    Text(AnyMetricsStrings.WidgetGuide.title)
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textColor)
                        .accessibilityIdentifier("widgetGuide.title")

                    Text(AnyMetricsStrings.WidgetGuide.subtitle(metricTitle))
                        .font(Constants.fontSubtitle)
                        .foregroundColor(Constants.secondaryColor)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Constants.stepSpacing) {
                    Text(AnyMetricsStrings.WidgetGuide.progress(stepIndex + 1, steps.count))
                        .font(Constants.fontSubtitle)
                        .foregroundColor(Constants.secondaryColor)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("widgetGuide.progress")

                    stepPager

                    pageDots
                }

                VStack(spacing: 16) {
                    Toggle(isOn: $dontShowAgain) {
                        Text(AnyMetricsStrings.WidgetGuide.dontShowAgain)
                            .font(Constants.fontSubtitle)
                            .foregroundColor(Constants.secondaryColor)
                    }

                    HStack(spacing: 12) {
                        Button {
                            guard stepIndex > 0 else { return }
                            ImpactHelper.impactButton()
                            withAnimation {
                                stepIndex -= 1
                            }
                        } label: {
                            Text(AnyMetricsStrings.WidgetGuide.back)
                                .font(Constants.fontButton)
                                .foregroundColor(Constants.secondaryColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .disabled(stepIndex == 0)
                        .accessibilityIdentifier("widgetGuide.back")

                        Button {
                            ImpactHelper.impactButton()
                            if isLastStep {
                                if dontShowAgain {
                                    AppSettings.hideWidgetInstructions = true
                                }
                                onDone(dontShowAgain)
                            } else {
                                withAnimation {
                                    stepIndex += 1
                                }
                            }
                        } label: {
                            Text(isLastStep ? AnyMetricsStrings.WidgetGuide.done : AnyMetricsStrings.WidgetGuide.next)
                                .font(Constants.fontButton)
                                .foregroundColor(Constants.textColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .background(Constants.buttonBackground)
                        .cornerRadius(Constants.buttonCorner)
                        .accessibilityIdentifier(isLastStep ? "widgetGuide.done" : "widgetGuide.next")
                    }
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
        }
        .frame(maxHeight: sheetHeight)
        .onPreferenceChange(SheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            sheetHeight = height
        }
        .modifier(FittedSheetModifier(height: sheetHeight))
    }

    private var stepPager: some View {
        Color.clear
            .frame(height: Constants.stepCardHeight)
            .overlay {
                TabView(selection: $stepIndex) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepCard(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .clipped()
    }

    private func stepCard(_ step: Step) -> some View {
        VStack(spacing: 12) {
            WidgetGuideDemoView(step: step.id, system: system, metricTitle: metricTitle)

            Text(step.text)
                .font(Constants.fontSubtitle)
                .foregroundColor(Constants.textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("widgetGuide.step")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Constants.stepCardCorner, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.stepCardCorner, style: .continuous))
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(steps) { step in
                Circle()
                    .fill(step.id == currentStep.id ? Constants.textColor : Constants.secondaryColor.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
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
        content
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview("iOS 18") {
    WidgetInstructionsView(metricTitle: "Server Status", system: .ios18, onDone: { _ in })
        .preferredColorScheme(.dark)
}

#Preview("iOS 16") {
    WidgetInstructionsView(metricTitle: "Server Status", system: .ios16, onDone: { _ in })
        .preferredColorScheme(.dark)
}
#endif
