import Foundation
import SwiftUI

private struct AppTodayKey: EnvironmentKey {
    static let defaultValue = Date()
}

public extension EnvironmentValues {
    /// "Today" for streaks, the daily feed and the widget. Pinned by
    /// `SCROLL_FIXED_DATE` during snapshots so captures are reproducible.
    var appToday: Date {
        get { self[AppTodayKey.self] }
        set { self[AppTodayKey.self] = newValue }
    }
}
