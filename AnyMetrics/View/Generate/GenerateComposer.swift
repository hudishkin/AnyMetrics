import SwiftUI

struct GenerateComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var placeholder: String
    var fieldIdentifier: String
    var isWaiting: Bool = false
    var onSend: () -> Void

    private let sendInset: CGFloat = 6

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: GenerateMetricView.Constants.composerCorner,
            style: .continuous
        )
        HStack(alignment: .bottom, spacing: 0) {
            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(GenerateMetricView.Constants.inputFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .focused(isFocused)
                .disabled(isWaiting)
                .lineLimit(1...GenerateMetricView.Constants.composerMaxLines)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, isWaiting ? 16 : 8)
                .padding(.vertical, 11)
                .frame(
                    minHeight: GenerateMetricView.Constants.sendButtonSize + sendInset * 2,
                    alignment: .center
                )
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        WaitingPlaceholder(text: placeholder, active: isWaiting)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier(fieldIdentifier)

            Button {
                guard canSend else { return }
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GenerateMetricView.Constants.sendIconColor)
                    .frame(
                        width: GenerateMetricView.Constants.sendButtonSize,
                        height: GenerateMetricView.Constants.sendButtonSize
                    )
                    .background(
                        Circle().fill(
                            canSend
                                ? GenerateMetricView.Constants.textColor
                                : GenerateMetricView.Constants.sendDisabledFill
                        )
                    )
                    .animation(.easeOut(duration: 0.15), value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(isWaiting ? 0 : 1)
            .allowsHitTesting(!isWaiting)
            .accessibilityHidden(isWaiting)
            .frame(width: isWaiting ? 0 : nil, alignment: .center)
            .clipped()
            .padding(.trailing, isWaiting ? 0 : sendInset)
            .padding(.vertical, sendInset)
            .accessibilityIdentifier("generate.send")
            .accessibilityLabel(AnyMetricsStrings.Generate.send)
        }
        .background(shape.fill(Color(uiColor: .systemBackground)))
        .overlay {
            AIGradientBorder(cornerRadius: GenerateMetricView.Constants.composerCorner)
        }
        .clipShape(shape)
        .padding(.horizontal, 16)
    }
}

/// Full-width button that takes the composer's place: Try again, Generate New.
struct GenerateDockButton: View {
    var title: String
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button {
            ImpactHelper.impactButton()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .frame(maxWidth: .infinity)
                .frame(height: GenerateMetricView.Constants.sendButtonSize + 12)
                .background(
                    RoundedRectangle(cornerRadius: GenerateMetricView.Constants.composerCorner, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier(identifier)
    }
}

/// Example prompts above an empty composer.
struct GenerateExamples: View {
    var examples: [GenerateMetricView.ExamplePrompt]
    var onSelect: (GenerateMetricView.ExamplePrompt) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GenerateMetricView.Constants.chipSpacing) {
                ForEach(examples) { example in
                    Button {
                        ImpactHelper.impactLight()
                        onSelect(example)
                    } label: {
                        HStack(spacing: 6) {
                            Text(example.emoji)
                            Text(example.title)
                                .lineLimit(1)
                        }
                        .font(GenerateMetricView.Constants.chipFont)
                        .foregroundColor(GenerateMetricView.Constants.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(GenerateMetricView.Constants.chipFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("generate.example.\(example.id)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
        }
        .frame(height: 42)
    }
}

/// A soft light moves across the waiting placeholder. Time drives it, so a parent spring cannot hitch the sweep.
private struct WaitingPlaceholder: View {
    var text: String
    var active: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !active)) { timeline in
            Text(text)
                .font(GenerateMetricView.Constants.inputFont)
                .foregroundStyle(style(at: timeline.date))
                .lineLimit(1)
        }
        .accessibilityLabel(text)
    }

    private func style(at date: Date) -> AnyShapeStyle {
        if reduceMotion || !active {
            return AnyShapeStyle(GenerateMetricView.Constants.secondaryColor)
        }
        let period = 1.6
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        let shift = -0.8 + phase * 2.0
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    GenerateMetricView.Constants.secondaryColor.opacity(0.4),
                    GenerateMetricView.Constants.textColor,
                    GenerateMetricView.Constants.secondaryColor.opacity(0.4)
                ],
                startPoint: UnitPoint(x: shift, y: 0.5),
                endPoint: UnitPoint(x: shift + 0.6, y: 0.5)
            )
        )
    }
}
