//
//  AppConfig.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation

enum AppConfig {

    static let group = "group.anymetrics.app"
    static let metricsKey = "app.metrics"

    enum Urls {
        static let appRepository = URL(string: "https://github.com/hudishkin/AnyMetrics")!
        static let galleryRepository = URL(string: "https://github.com/hudishkin/AnyMetricsGallery")!
        static let rules = URL(string: "https://github.com/hudishkin/AnyMetrics")!

        static let gallery = URL(string: "https://raw.githubusercontent.com/hudishkin/AnyMetricsGallery/main/list.min.json")!
    }

    static let isiOSAppOnMac: Bool = {
        var isiOSAppOnMac = false
        if #available(iOS 14.0, *) {
            isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
        }
        return isiOSAppOnMac
    }()
}
