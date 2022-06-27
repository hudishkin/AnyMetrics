//
//  Bundle+Widget.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 20.06.2022.
//

import Foundation


extension Bundle {
    static func isInWidget() -> Bool {
        guard let extesion = Bundle.main.infoDictionary?["NSExtension"] as? [String: String] else { return false }
        guard let widget = extesion["NSExtensionPointIdentifier"] else { return false }
        return widget == "com.apple.widgetkit-extension"
    }
}
