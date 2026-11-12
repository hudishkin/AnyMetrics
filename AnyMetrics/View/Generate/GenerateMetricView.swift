import SwiftUI
import VVSI

struct GenerateMetricView: View {

    @StateObject
    private var viewState: ViewState<Interactor> = .init(Interactor())
    @FocusState
    private var isComposerFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                hero
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                examples
                composer
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(Color(uiColor: .systemBackground))
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            RobotGradientWash(direction: .down, softness: 0.92, opacity: 0.5)
                .frame(height: Constants.glowHeight)
                .ignoresSafeArea(edges: .top)
        }
        .navigationTitle(AnyMetricsStrings.Generate.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    GenerateHistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Constants.textColor)
                }
                .accessibilityIdentifier("generate.history")
                .accessibilityLabel(AnyMetricsStrings.Generate.history)
            }
        }
        .tint(Constants.textColor)
        .onAppear {
            viewState.trigger(.onAppear)
        }
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .submitted:
                isComposerFocused = false
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            RobotFaceView(size: Constants.robotSize, kind: .glance)
            SpeechBubble(
                text: AnyMetricsStrings.Generate.greeting,
                tilt: .degrees(-3)
            )
            .padding(.top, Constants.robotSize - Constants.bubbleOverlap)
        }
    }

    private var examples: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.chipSpacing) {
                ForEach(viewState.state.examples) { example in
                    Button {
                        ImpactHelper.impactLight()
                        viewState.trigger(.selectExample(example.id))
                        isComposerFocused = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(example.emoji)
                            Text(example.title)
                                .lineLimit(1)
                        }
                        .font(Constants.chipFont)
                        .foregroundColor(Constants.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Constants.chipFill))
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

    private var composer: some View {
        GenerateComposer(
            text: Binding(
                get: { viewState.state.draft },
                set: { viewState.trigger(.setDraft($0)) }
            ),
            isFocused: $isComposerFocused,
            onSend: {
                ImpactHelper.impactButton()
                viewState.trigger(.send)
            }
        )
    }
}

private struct GenerateComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField(AnyMetricsStrings.Generate.placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(GenerateMetricView.Constants.inputFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .focused(isFocused)
                .lineLimit(1...GenerateMetricView.Constants.composerMaxLines)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 11)
                .accessibilityIdentifier("generate.draft")

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
                        Circle().fill(GenerateMetricView.Constants.textColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
            .padding(.bottom, 5)
            .accessibilityIdentifier("generate.send")
            .accessibilityLabel(AnyMetricsStrings.Generate.send)
        }
        .background(
            RoundedRectangle(cornerRadius: GenerateMetricView.Constants.composerCorner, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GenerateMetricView.Constants.composerCorner, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

#if DEBUG
struct GenerateMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GenerateMetricView()
        }
        .preferredColorScheme(.light)
    }
}
#endif
