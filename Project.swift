import ProjectDescription

let version = "2.0.0"
let buildNumber = "1"
let bundleId = "app.anymetrics.AnyMetrics"

let appInfoPlist: [String: Plist.Value] = [
    "CFBundleDisplayName": .string("AnyMetrics"),
    "NSAppTransportSecurity": .dictionary([
        "NSAllowsArbitraryLoads": .boolean(true)
    ]),
    "UIApplicationSceneManifest": .dictionary([
        "UIApplicationSupportsMultipleScenes": .boolean(false)
    ]),
    "UIApplicationSupportsIndirectInputEvents": .boolean(true),
    "UILaunchScreen": .dictionary([:]),
    "UISupportedInterfaceOrientations": .array([
        .string("UIInterfaceOrientationPortrait"),
        .string("UIInterfaceOrientationLandscapeLeft"),
        .string("UIInterfaceOrientationLandscapeRight")
    ]),
    "UISupportedInterfaceOrientations~ipad": .array([
        .string("UIInterfaceOrientationPortrait"),
        .string("UIInterfaceOrientationPortraitUpsideDown"),
        .string("UIInterfaceOrientationLandscapeLeft"),
        .string("UIInterfaceOrientationLandscapeRight")
    ]),
    "NSUserActivityTypes": .array([
        .string("ConfigurationIntent")
    ])
]

let widgetInfoPlist: [String: Plist.Value] = [
    "CFBundleIdentifier": .string("$(PRODUCT_BUNDLE_IDENTIFIER)"),
    "CFBundleDisplayName": .string("Widget"),
    "NSExtension": .dictionary([
        "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
    ])
]

let intentInfoPlist: [String: Plist.Value] = [
    "CFBundleIdentifier": .string("$(PRODUCT_BUNDLE_IDENTIFIER)"),
    "CFBundleDisplayName": .string("Intent"),
    "NSExtension": .dictionary([
        "NSExtensionAttributes": .dictionary([
            "IntentsRestrictedWhileLocked": .array([]),
            "IntentsRestrictedWhileProtectedDataUnavailable": .array([]),
            "IntentsSupported": .array([
                .string("ConfigurationIntent")
            ])
        ]),
        "NSExtensionPointIdentifier": .string("com.apple.intents-service"),
        "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).IntentHandler")
    ])
]

let sharedTarget: Target = .target(
    name: "AnyMetricsShared",
    destinations: .iOS,
    product: .framework,
    bundleId: "\(bundleId).Shared",
    deploymentTargets: .iOS("15.0"),
    infoPlist: .default,
    sources: [
        "AnyMetricsShared/**/*.swift"
    ],
    dependencies: [
        .external(name: "SwiftyJSON"),
        .external(name: "SwiftSoup")
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "SWIFT_VERSION": "5.0"
        ]
    )
)

let appTarget: Target = .target(
    name: "AnyMetrics",
    destinations: .iOS,
    product: .app,
    bundleId: bundleId,
    deploymentTargets: .iOS("15.0"),
    infoPlist: .extendingDefault(with: appInfoPlist),
    sources: [
        "AnyMetrics/**/*.swift",
        "Widget/Base.lproj/Widget.intentdefinition"
    ],
    resources: [
        "AnyMetrics/Resources/**",
        "AnyMetrics/Preview Content/**",
        "AnyMetrics/GoogleService-Info.plist"
    ],
    entitlements: .file(path: "AnyMetrics/AnyMetrics.entitlements"),
    scripts: [
        .post(
            script: """
            if [ "${CONFIGURATION}" != "Release" ] || [ "${PLATFORM_NAME}" = "iphonesimulator" ]; then
              echo "Skipping Crashlytics for ${CONFIGURATION} ${PLATFORM_NAME}"
              exit 0
            fi

            CRASHLYTICS_RUN="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
            if [ ! -f "${CRASHLYTICS_RUN}" ]; then
              echo "Crashlytics run script is missing at ${CRASHLYTICS_RUN}, skipping."
              exit 0
            fi

            "${CRASHLYTICS_RUN}"
            """,
            name: "Firebase",
            inputPaths: [
                "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
                "$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)"
            ]
        )
    ],
    dependencies: [
        .target(name: "AnyMetricsShared"),
        .target(name: "WidgetExtension"),
        .target(name: "Intent"),
        .external(name: "FirebaseAnalyticsCore"),
        .external(name: "FirebaseCrashlytics"),
        .external(name: "SwiftyJSON"),
        .external(name: "SwiftSoup"),
        .external(name: "Highlightr")
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "CURRENT_PROJECT_VERSION": .string(buildNumber),
            "MARKETING_VERSION": .string(version),
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "DEVELOPMENT_ASSET_PATHS": "\"AnyMetrics/Preview Content\"",
            "ENABLE_PREVIEWS": "YES",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"
        ]
    )
)

let widgetTarget: Target = .target(
    name: "WidgetExtension",
    destinations: .iOS,
    product: .appExtension,
    bundleId: "\(bundleId).WidgetExtension",
    deploymentTargets: .iOS("15.0"),
    infoPlist: .extendingDefault(with: widgetInfoPlist),
    sources: [
        "Widget/Widget.swift",
        "Intent/IntentHandler.swift",
        "Widget/Base.lproj/Widget.intentdefinition",
        "AnyMetrics/Extensions/TuistResources.swift",
        "AnyMetrics/View/Main/MetricContentView.swift",
        "AnyMetrics/Resources/Mocks.swift"
    ],
    resources: [
        "Widget/Assets.xcassets",
        "AnyMetrics/Resources/Assets.xcassets",
        "AnyMetrics/Resources/en.lproj/Localizable.strings",
        "AnyMetrics/Resources/ru.lproj/Localizable.strings"
    ],
    entitlements: .file(path: "WidgetExtension.entitlements"),
    dependencies: [
        .target(name: "AnyMetricsShared"),
        .sdk(name: "SwiftUI", type: .framework),
        .sdk(name: "WidgetKit", type: .framework)
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "CURRENT_PROJECT_VERSION": "1",
            "MARKETING_VERSION": "1.2",
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "SWIFT_VERSION": "5.0",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) WIDGET_EXTENSION",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "SKIP_INSTALL": "YES",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME": "WidgetBackground"
        ]
    )
)

let intentTarget: Target = .target(
    name: "Intent",
    destinations: .iOS,
    product: .appExtension,
    bundleId: "\(bundleId).IntentExtension",
    deploymentTargets: .iOS("15.0"),
    infoPlist: .extendingDefault(with: intentInfoPlist),
    sources: [
        "Intent/IntentHandler.swift",
        "Widget/Base.lproj/Widget.intentdefinition"
    ],
    entitlements: .file(path: "Intent/Intent.entitlements"),
    dependencies: [
        .target(name: "AnyMetricsShared"),
        .sdk(name: "Intents", type: .framework)
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "CURRENT_PROJECT_VERSION": "1",
            "MARKETING_VERSION": "1.2",
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "SKIP_INSTALL": "YES",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"
        ]
    )
)

let unitTestsTarget: Target = .target(
    name: "AnyMetricsTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundleId).AnyMetricsTests",
    deploymentTargets: .iOS("15.4"),
    infoPlist: .default,
    sources: ["AnyMetricsTests/**/*.swift"],
    dependencies: [.target(name: "AnyMetrics")],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "CURRENT_PROJECT_VERSION": "1",
            "MARKETING_VERSION": "1.0",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/AnyMetrics.app/AnyMetrics"
        ]
    )
)

let uiTestsTarget: Target = .target(
    name: "AnyMetricsUITests",
    destinations: .iOS,
    product: .uiTests,
    bundleId: "\(bundleId).AnyMetricsUITests",
    deploymentTargets: .iOS("15.0"),
    infoPlist: .default,
    sources: ["AnyMetricsUITests/**/*.swift"],
    dependencies: [.target(name: "AnyMetrics")],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "Q424U5CAPS",
            "CURRENT_PROJECT_VERSION": "1",
            "MARKETING_VERSION": "1.0",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "TEST_TARGET_NAME": "AnyMetrics"
        ]
    )
)

let project = Project(
    name: "AnyMetrics",
    settings: .settings(
        base: [
            "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
            "SWIFT_VERSION": "5.0"
        ],
        defaultSettings: .recommended
    ),
    targets: [
        sharedTarget,
        appTarget,
        unitTestsTarget,
        uiTestsTarget,
        widgetTarget,
        intentTarget
    ]
)
