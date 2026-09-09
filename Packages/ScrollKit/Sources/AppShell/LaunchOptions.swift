import Foundation

/// Everything the process environment tells the app about how it was started.
/// Parsed once in `RootView` so screenshots and UI tests are deterministic.
public struct LaunchOptions: Equatable, Sendable {
    /// Set by `--screenshot <id>`: route straight to that screen with fixture data.
    public let screenshot: ScreenRoute?
    /// Set by `SCROLL_FIXED_DATE=2026-09-14`: pins "today" so streaks and feeds are stable.
    public let fixedDate: Date?
    /// Set by `--ui-test`: skip the first-run funnel and use fixture commerce, so a test
    /// that is not about onboarding starts on the tab bar.
    public let isUITest: Bool
    /// Set by `--open-url <url>`: the deep link to replay at launch. The UI tests use it
    /// where they cannot reach `simctl openurl`; the real entry point is `onOpenURL`.
    public let openURL: URL?

    public init(
        screenshot: ScreenRoute? = nil,
        fixedDate: Date? = nil,
        isUITest: Bool = false,
        openURL: URL? = nil
    ) {
        self.screenshot = screenshot
        self.fixedDate = fixedDate
        self.isUITest = isUITest
        self.openURL = openURL
    }

    public init(arguments: [String], environment: [String: String]) {
        screenshot = LaunchOptions.value(of: "--screenshot", in: arguments).flatMap(ScreenRoute.init(rawValue:))
        isUITest = arguments.contains("--ui-test")
        openURL = LaunchOptions.value(of: "--open-url", in: arguments).flatMap(URL.init(string:))

        if let raw = environment["SCROLL_FIXED_DATE"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd"
            fixedDate = formatter.date(from: raw)
        } else {
            fixedDate = nil
        }
    }

    /// The value following `flag`, or nil when the flag is absent or last.
    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else { return nil }
        return arguments[next]
    }

    /// True when the app is being driven headlessly for a snapshot.
    public var isSnapshotRun: Bool {
        screenshot != nil
    }

    /// Snapshots and UI tests get `MockEntitlementStore` instead of live StoreKit: a
    /// capture has to quote the same prices every time, with no store round-trip.
    public var usesFixtureCommerce: Bool {
        isSnapshotRun || isUITest
    }

    /// True when the first-run funnel should be skipped regardless of stored preferences.
    public var startsOnTabs: Bool {
        isUITest || openURL != nil
    }

    public static let live = LaunchOptions(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )
}
