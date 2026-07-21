//
//  Haptic.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 19.06.2022.
//

import UIKit

enum ImpactHelper {

    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    static func impactButton() {
        softGenerator.prepare()
        softGenerator.impactOccurred()
    }

    static func impactLight() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }

    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
}
