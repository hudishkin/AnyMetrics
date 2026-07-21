import SwiftUI
import UIKit
import Highlightr
import AnyMetricsShared

struct CodeView: UIViewRepresentable {

    enum CodeType: String {
        case json, html
    }

    @Binding var code: String
    @Binding var codeType: CodeType
    var onSelectParseRule: ((String) -> Void)?

    private let highlightr = Highlightr()

    init(
        code: Binding<String>,
        codeType: Binding<CodeType>,
        onSelectParseRule: ((String) -> Void)? = nil
    ) {
        self._code = code
        self._codeType = codeType
        self.onSelectParseRule = onSelectParseRule
        let theme: String
        if UITraitCollection.current.userInterfaceStyle == .dark {
            theme = "atelier-cave-dark"
        } else {
            theme = "atelier-cave-light"
        }
        highlightr?.setTheme(to: theme)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectParseRule: onSelectParseRule)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = onSelectParseRule == nil
        textView.backgroundColor = .systemGroupedBackground
        textView.textContainer.lineFragmentPadding = 20
        textView.delegate = context.coordinator

        if onSelectParseRule != nil {
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            textView.addGestureRecognizer(tap)
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onSelectParseRule = onSelectParseRule
        context.coordinator.contentType = contentType(for: codeType)

        if context.coordinator.storedCode != code {
            context.coordinator.storedCode = code
            context.coordinator.baseAttributedText = highlightr?.highlight(code, as: codeType.rawValue)
            context.coordinator.selectedRange = nil
        }

        context.coordinator.tapTargets = onSelectParseRule != nil
            ? ParseRulePathBuilder.tapTargets(in: code, type: context.coordinator.contentType)
            : []

        context.coordinator.applyAppearance(to: uiView)
    }

    private func contentType(for codeType: CodeType) -> ParseRulePathBuilder.ContentType {
        switch codeType {
        case .json:
            return .json
        case .html:
            return .html
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onSelectParseRule: ((String) -> Void)?
        var tapTargets: [ParseRulePathBuilder.TapTarget] = []
        var contentType: ParseRulePathBuilder.ContentType = .json
        var storedCode = ""
        var baseAttributedText: NSAttributedString?
        var selectedRange: NSRange?

        init(onSelectParseRule: ((String) -> Void)?) {
            self.onSelectParseRule = onSelectParseRule
            super.init()
        }

        func applyAppearance(to textView: UITextView) {
            guard let base = baseAttributedText?.mutableCopy() as? NSMutableAttributedString else {
                if let fallback = baseAttributedText {
                    textView.attributedText = fallback
                }
                return
            }

            if onSelectParseRule != nil {
                let underlineColor = UIColor.tintColor.withAlphaComponent(0.55)
                let underlineStyle = NSUnderlineStyle.single.union(.patternDot).rawValue

                for target in tapTargets {
                    let range = target.range
                    guard range.location != NSNotFound,
                          NSMaxRange(range) <= base.length else { continue }

                    base.addAttributes([
                        .underlineStyle: underlineStyle,
                        .underlineColor: underlineColor
                    ], range: range)
                }
            }

            if let selectedRange,
               selectedRange.location != NSNotFound,
               NSMaxRange(selectedRange) <= base.length {
                base.addAttribute(
                    .backgroundColor,
                    value: UIColor.tintColor.withAlphaComponent(0.22),
                    range: selectedRange
                )
            }

            textView.attributedText = base
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView,
                  let onSelectParseRule else { return }

            let point = gesture.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return }

            let location = textView.offset(from: textView.beginningOfDocument, to: position)
            guard let target = ParseRulePathBuilder.tapTarget(at: location, in: tapTargets) else { return }

            selectedRange = target.range
            applyAppearance(to: textView)

            ImpactHelper.impactLight()
            onSelectParseRule(target.parseRule)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.selectedRange = nil
                self.applyAppearance(to: textView)
            }
        }
    }
}
