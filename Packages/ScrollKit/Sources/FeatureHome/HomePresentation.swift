import Foundation

/// The line under the streak count. Pure so the copy can be asserted without a view.
public enum StreakMotivation {
    public static func line(forStreak streak: Int) -> String {
        switch streak {
        case ..<1:
            "Open the Quran today and your streak starts."
        case 1:
            "Great start. Come back tomorrow to keep it going."
        case 2 ... 6:
            "\(streak) days in a row. Keep it going."
        case 7 ... 29:
            "\(streak) days in a row. That is a habit now."
        default:
            "\(streak) days in a row. Remarkable."
        }
    }

    /// `"1 DAYS OPENED"` reads badly in the reference too, but it is what the card prints;
    /// the caption is fixed copy and the number carries the count.
    public static let daysOpenedCaption = "Days opened"
}

/// How one dot of the Monday–Sunday week row is drawn.
public enum StreakDotStyle: String, Hashable, Sendable {
    /// The app was opened that day: filled with the flame gradient.
    case opened
    /// Today, and opened: filled, with the ring around it.
    case today
    /// Today, not opened yet: empty, with the ring around it.
    case todayPending
    /// A past day that was missed, or a day later this week: an empty well.
    case empty

    public static func forDay(isOpened: Bool, isToday: Bool, isFuture: Bool) -> StreakDotStyle {
        if isToday {
            return isOpened ? .today : .todayPending
        }
        if isFuture {
            return .empty
        }
        return isOpened ? .opened : .empty
    }

    /// The dot carries the flame gradient rather than the flat well colour.
    public var isFilled: Bool {
        self == .opened || self == .today
    }

    /// Today's dot is ringed, opened or not.
    public var isRinged: Bool {
        self == .today || self == .todayPending
    }
}

/// The two lines of the "% Quran read" card. `percentLabel` and `versesLabel` come straight
/// from `UserState.ReadProgress`, which owns the "<1%" rule; this type only decides the caption
/// and the bar fraction so the card has no arithmetic in its body.
public struct ReadProgressSummary: Hashable, Sendable {
    public static let totalVerses = 6236
    public static let caption = "Quran read"

    public let readCount: Int

    public init(readCount: Int) {
        self.readCount = max(0, readCount)
    }

    /// 0...1, for the `ProgressBar`.
    public var fraction: Double {
        guard Self.totalVerses > 0 else { return 0 }
        return min(1, Double(readCount) / Double(Self.totalVerses))
    }
}
