// swift-tools-version: 5.10
import PackageDescription

/// Every target of the app lives here. This manifest is declared once in Phase 1 and
/// then frozen: later phases add files by dropping them into the globbed Sources folders.
let package = Package(
    name: "ScrollKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QuranData", targets: ["QuranData"]),
        .library(name: "StudyContent", targets: ["StudyContent"]),
        .library(name: "UserState", targets: ["UserState"]),
        .library(name: "Commerce", targets: ["Commerce"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"]),
        .library(name: "FeaturePaywall", targets: ["FeaturePaywall"]),
        .library(name: "FeatureReader", targets: ["FeatureReader"]),
        .library(name: "FeatureDiscover", targets: ["FeatureDiscover"]),
        .library(name: "FeatureHome", targets: ["FeatureHome"]),
        .library(name: "FeatureCommunity", targets: ["FeatureCommunity"]),
        .library(name: "AppShell", targets: ["AppShell"]),
    ],
    targets: [
        // MARK: - Foundations (Foundation only, host-testable)

        .target(name: "QuranData"),
        .target(name: "StudyContent", dependencies: ["QuranData"]),
        .target(name: "UserState", dependencies: ["QuranData"]),
        .target(name: "Commerce"),

        // MARK: - Design system (owns the bundled fonts)

        .target(
            name: "DesignSystem",
            resources: [.copy("Resources/Fonts")]
        ),

        // MARK: - Features (one public entry view each)

        .target(name: "FeatureOnboarding", dependencies: ["DesignSystem", "UserState"]),
        .target(name: "FeaturePaywall", dependencies: ["DesignSystem", "Commerce"]),
        .target(name: "FeatureReader", dependencies: ["DesignSystem", "QuranData", "StudyContent", "UserState"]),
        .target(name: "FeatureDiscover", dependencies: ["DesignSystem", "QuranData", "StudyContent", "UserState"]),
        .target(name: "FeatureHome", dependencies: ["DesignSystem", "QuranData", "UserState"]),
        .target(name: "FeatureCommunity", dependencies: ["DesignSystem", "UserState"]),

        // MARK: - Composition root

        .target(
            name: "AppShell",
            dependencies: [
                "QuranData", "StudyContent", "UserState", "Commerce", "DesignSystem",
                "FeatureOnboarding", "FeaturePaywall", "FeatureReader",
                "FeatureDiscover", "FeatureHome", "FeatureCommunity",
            ]
        ),

        // MARK: - Tests (one target per source target, Swift Testing)

        .testTarget(name: "QuranDataTests", dependencies: ["QuranData"]),
        .testTarget(name: "StudyContentTests", dependencies: ["StudyContent"]),
        .testTarget(name: "UserStateTests", dependencies: ["UserState"]),
        .testTarget(name: "CommerceTests", dependencies: ["Commerce"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "FeatureOnboardingTests", dependencies: ["FeatureOnboarding"]),
        .testTarget(name: "FeaturePaywallTests", dependencies: ["FeaturePaywall"]),
        .testTarget(name: "FeatureReaderTests", dependencies: ["FeatureReader"]),
        .testTarget(name: "FeatureDiscoverTests", dependencies: ["FeatureDiscover"]),
        .testTarget(name: "FeatureHomeTests", dependencies: ["FeatureHome"]),
        .testTarget(name: "FeatureCommunityTests", dependencies: ["FeatureCommunity"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
    ]
)
