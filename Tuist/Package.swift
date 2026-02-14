// swift-tools-version: 5.9

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "SwiftyJSON": .framework,
        "SwiftSoup": .framework,
        "LRUCache": .framework,
        "Atomics": .framework
    ]
)
#endif

import PackageDescription

let package = Package(
    name: "AnyMetricsDependencies",
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.9.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.0.0"),
        .package(url: "https://github.com/hudishkin/vvsi.git", from: "0.1.1")
    ]
)
