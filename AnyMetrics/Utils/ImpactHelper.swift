//
//  Haptic.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 19.06.2022.
//

import UIKit

enum ImpactHelper {

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func impactButton() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .soft)
        impactHeavy.impactOccurred()
    }
}
