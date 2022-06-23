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
        static let rules = URL(string: "http://ya.ru")!

        static let gallery = URL(string: "https://raw.githubusercontent.com/hudishkin/AnyMetricsGallery/main/list.json")!
    }

    static let isiOSAppOnMac: Bool = {
        var isiOSAppOnMac = false
        if #available(iOS 14.0, *) {
            isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
        }
        return isiOSAppOnMac
    }()
}
