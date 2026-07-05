// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-internalize-at-link",
        "-Xfrontend", "-lto=llvm-full",
        "-Xfrontend", "-conditional-runtime-records"
    ])
]

let linkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-dead_strip"])
]

let runtimeDependency: Target.Dependency = .product(
    name: "SwiftGodotRuntime",
    package: "SwiftGodotBinary"
)

func docResource(_ name: String) -> Resource {
    .embedInCode("../../doc_classes/\(name).xml")
}

let avFoundationDocResources = [
    "AVAudioSession",
].map(docResource)

let foundationDocResources = [
    "AppleFilePicker",
    "AppleURL",
    "Foundation",
    "NSUbiquitousKeyValueStore",
    "SignalProxy",
].map(docResource)

let gameCenterDocResources = [
    "GKAccessPoint",
    "GKAchievement",
    "GKAchievementChallenge",
    "GKAchievementDescription",
    "GKChallenge",
    "GKChallengeDefinition",
    "GKError",
    "GKGameActivity",
    "GKGameActivityDefinition",
    "GKGameCenterViewController",
    "GKInvite",
    "GKLeaderboard",
    "GKLeaderboardEntry",
    "GKLeaderboardScore",
    "GKLeaderboardSet",
    "GKLocalPlayer",
    "GKMatch",
    "GKMatchRequest",
    "GKMatchmaker",
    "GKMatchmakerViewController",
    "GKNotificationBanner",
    "GKPlayer",
    "GKSavedGame",
    "GKScoreChallenge",
    "GKTurnBasedExchange",
    "GKTurnBasedExchangeReply",
    "GKTurnBasedMatch",
    "GKTurnBasedMatchmakerViewController",
    "GKTurnBasedParticipant",
    "GKVoiceChat",
    "GameCenterManager",
].map(docResource)

let storeKitDocResources = [
    "ProductView",
    "StoreKitManager",
    "StoreProduct",
    "StoreProductPaymentMode",
    "StoreProductPurchaseOption",
    "StoreProductSubscriptionOffer",
    "StoreProductSubscriptionPeriod",
    "StoreSubscriptionInfo",
    "StoreSubscriptionInfoRenewalInfo",
    "StoreSubscriptionInfoStatus",
    "StoreTransaction",
    "StoreView",
    "SubscriptionOfferView",
    "SubscriptionStoreView",
].map(docResource)

let authenticationServicesDocResources = [
    "ASAuthorizationAppleIDCredential",
    "ASAuthorizationController",
    "ASPasswordCredential",
    "ASWebAuthenticationSession",
].map(docResource)

let arKitDocResources = [
    "ARAnchor",
    "ARBodyAnchor",
    "ARBodySkeleton",
    "ARBodyTrackingConfiguration",
    "ARCamera",
    "ARCoachingOverlay",
    "ARCollaborationData",
    "AREnvironmentProbeAnchor",
    "ARFaceAnchor",
    "ARFrame",
    "ARGeoAnchor",
    "ARGeoTrackingConfiguration",
    "ARHandAnchor",
    "ARHandSkeleton",
    "ARImageAnchor",
    "ARLightEstimate",
    "ARMeshAnchor",
    "ARPlaneAnchor",
    "ARPointCloud",
    "ARRaycastQuery",
    "ARRaycastResult",
    "ARSession",
    "ARTrackedRaycast",
    "ARWorldMap",
    "ARWorldTrackingConfiguration",
].map(docResource)

let keychainDocResources = [
    "Keychain",
].map(docResource)

let coreMotionDocResources = [
    "CMAbsoluteAltitudeData",
    "CMAccelerometerData",
    "CMAltimeter",
    "CMAltitudeData",
    "CMDeviceMotion",
    "CMGyroData",
    "CMHeadphoneMotionManager",
    "CMMagnetometerData",
    "CMMotionActivity",
    "CMMotionActivityManager",
    "CMMotionManager",
    "CMPedometer",
    "CMPedometerData",
].map(docResource)

func pluginTarget(name: String, path: String, exclude: [String] = [], resources: [Resource] = []) -> Target {
    .target(
        name: name,
        dependencies: [runtimeDependency],
        path: path,
        exclude: exclude,
        resources: resources,
        swiftSettings: swiftSettings,
        linkerSettings: linkerSettings
    )
}

let package = Package(
    name: "GodotApplePlugins",
    platforms: [
        .iOS(.v17),
        .macOS("14.0"),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "GodotApplePlugins",
            type: .dynamic,
            targets: ["GodotApplePlugins"]
        ),
        .library(
            name: "GodotApplePluginsAVFoundation",
            type: .dynamic,
            targets: ["GodotApplePluginsAVFoundation"]
        ),
        .library(
            name: "GodotApplePluginsFoundation",
            type: .dynamic,
            targets: ["GodotApplePluginsFoundation"]
        ),
        .library(
            name: "GodotApplePluginsGameCenter",
            type: .dynamic,
            targets: ["GodotApplePluginsGameCenter"]
        ),
        .library(
            name: "GodotApplePluginsStoreKit",
            type: .dynamic,
            targets: ["GodotApplePluginsStoreKit"]
        ),
        .library(
            name: "GodotApplePluginsAuthenticationServices",
            type: .dynamic,
            targets: ["GodotApplePluginsAuthenticationServices"]
        ),
        .library(
            name: "GodotApplePluginsARKit",
            type: .dynamic,
            targets: ["GodotApplePluginsARKit"]
        ),
        .library(
            name: "GodotApplePluginsCoreMotion",
            type: .dynamic,
            targets: ["GodotApplePluginsCoreMotion"]
        ),
        .library(
            name: "GodotApplePluginsKeychain",
            type: .dynamic,
            targets: ["GodotApplePluginsKeychain"]
        ),
        .executable(
            name: "GodotApplePluginsStubGenerator",
            targets: ["GodotApplePluginsStubGenerator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodotBinary", revision: "bf7cd9cb51b30039199c47811c486976923af93e")
        // For local development:
        //.package(path: "../SwiftGodot")
    ],
    targets: [
        .target(
            name: "GodotApplePlugins",
            dependencies: [
                runtimeDependency,
                "GodotApplePluginsAVFoundation",
                "GodotApplePluginsFoundation",
                "GodotApplePluginsGameCenter",
                "GodotApplePluginsStoreKit",
                "GodotApplePluginsAuthenticationServices",
                "GodotApplePluginsARKit",
                "GodotApplePluginsCoreMotion",
                "GodotApplePluginsKeychain",
            ],
            path: "Sources/GodotApplePlugins",
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        ),
        pluginTarget(
            name: "GodotApplePluginsAVFoundation",
            path: "Sources/GodotAVFoundation",
            resources: avFoundationDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsFoundation",
            path: "Sources/GodotFoundation",
            exclude: ["FoundationGuide.md"],
            resources: foundationDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsGameCenter",
            path: "Sources/GodotGameCenter",
            exclude: [
                "Entitlements.md",
                "GameCenterGuide.md",
            ],
            resources: gameCenterDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsStoreKit",
            path: "Sources/GodotStoreKit",
            exclude: ["StoreKitGuide.md"],
            resources: storeKitDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsAuthenticationServices",
            path: "Sources/GodotAuthenticationServices",
            exclude: ["AuthenticationServicesGuide.md"],
            resources: authenticationServicesDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsARKit",
            path: "Sources/GodotARKit",
            exclude: ["ARKitGuide.md"],
            resources: arKitDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsCoreMotion",
            path: "Sources/GodotCoreMotion",
            exclude: ["CoreMotionGuide.md"],
            resources: coreMotionDocResources
        ),
        pluginTarget(
            name: "GodotApplePluginsKeychain",
            path: "Sources/GodotKeychain",
            exclude: ["KeychainGuide.md"],
            resources: keychainDocResources
        ),
        .executableTarget(
            name: "GodotApplePluginsStubGenerator"
        ),
    ]
)
