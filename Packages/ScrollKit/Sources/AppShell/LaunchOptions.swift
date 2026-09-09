import Foundation

/// Everything the process environment tells the app about how it was started.
/// Parsed once in `RootView` so screenshots and UI tests are deterministic.
public struct LaunchOptions: Equatable, Sendable {
    /// Set by `--screenshot <id>`: route straight to that screen with fixture data.
    public let screenshot: ScreenRoute?
    /// Set by `SCROLL_FIXED_DATE=2026-09-14`: pins "today" so streaks and feeds are stable.
    public let fixedDate: Date?

    public init(screenshot: ScreenRoute? = nil, fixedDate: Date? = nil) {
        self.screenshot = screenshot
        self.fixedDate = fixedDate
    }

    public init(arguments: [String], environment: [String: String]) {
        var route: ScreenRoute?
        if let flag = arguments.firstIndex(of: "--screenshot"), arguments.index(after: flag) < arguments.endIndex {
            route = ScreenRoute(rawValue: arguments[arguments.index(after: flag)])
        }
        screenshot = route

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

    /// True when the app is being driven headlessly for a snapshot.
    public var isSnapshotRun: Bool {
        screenshot != nil
    }

    public static let live = LaunchOptions(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )
}
