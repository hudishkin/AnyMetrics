//
//  AnyMetricsApp.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    #if DEBUG
    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
        return true
    }
    #endif

    guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
        return true
    }

    guard
        let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
        let options = FirebaseOptions(contentsOfFile: path)
    else {
        return true
    }

    FirebaseApp.configure(options: options)

    return true
  }
}

@main
struct AnyMetricsApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel())
        }
    }
}
