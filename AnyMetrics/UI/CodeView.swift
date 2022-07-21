//
//  CodeView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.07.2022.
//

import SwiftUI
import Highlightr

struct CodeView: UIViewRepresentable {

    enum CodeType: String {
        case json, html
    }
    
    @Binding var code: String
    @Binding var codeType: CodeType

    private let highlightr = Highlightr()

    init(code: Binding<String>, codeType: Binding<CodeType>) {
        self._code = code
        self._codeType = codeType
        let theme: String
        if UITraitCollection.current.userInterfaceStyle == .dark {
            theme = "atelier-cave-dark"
        } else {
            theme = "atelier-cave-light"
        }
        highlightr?.setTheme(to: theme)

    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .systemGroupedBackground
        textView.textContainer.lineFragmentPadding = 20
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText.string == code {
            return
        }
        if let highlightText = highlightr?.highlight(code, as: self.codeType.rawValue) {
            uiView.attributedText = highlightText
        }
    }

}
