//
//  ReviewHandler.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 29.06.2022.
//

import Foundation
import StoreKit
import SwiftUI

enum ReviewHandler {

    static func requestReview() {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
