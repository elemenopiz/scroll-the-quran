import Foundation
import QuranData

/// Seeded user state for `--screenshot` runs and UI tests.
///
/// A capture of Home has to show what the reference shows: a plan running, a streak with
/// real dots in the week row, and some of the Quran read. A freshly installed app shows
/// none of that — "Pick a plan to begin", a zero streak, an empty progress bar — so the
/// reference and the capture disagree about *content* before they ever disagree about
/// layout, and the score stops measuring the design.
///
/// The launch argument is read here rather than in the shell: `UserStore.shared()` is
/// already the one place that decides what the running app's state is, so seeding needs
/// no hook in `AppShell` and no change to `LaunchOptions`.
///
///     xcrun simctl launch <udid> com.quranscroller.app \
///       --screenshot home#scrolled --fixture-state premium-active-plan
///
/// Seeding never touches the App Group container: a fixture store is backed by memory, so
/// a capture run cannot leave a plan or a streak behind for the next real launch.
public enum FixtureState: String, CaseIterable, Sendable {
    /// A subscriber a few weeks in: `juz-a-day` running since day 6, a seven-day streak,
    /// and the first four surahs read.
    case premiumActivePlan = "premium-active-plan"
    /// A brand-new install. Explicit, so a capture can ask for the empty states.
    case fresh

    /// The launch argument that selects a fixture, e.g. `--fixture-state premium-active-plan`.
    public static let flag = "--fixture-state"

    /// The fixture named on the command line, if any.
    public static func requested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> FixtureState? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else { return nil }
        return FixtureState(rawValue: arguments[next])
    }

    /// "Today" for a seeded run. `SCROLL_FIXED_DATE` pins the whole capture, so the
    /// seeded streak and plan day have to be laid out relative to the same date.
    public static func fixedDate(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Date? {
        guard let raw = environment["SCROLL_FIXED_DATE"] else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}

@MainActor
public extension UserStore {
    /// A memory-backed store already in the given state. Used by `shared()` under
    /// `--fixture-state`, and directly by tests.
    static func fixture(
        _ fixture: FixtureState,
        today: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> UserStore {
        let store = UserStore(fileStore: MemoryUserStateFileStore(), calendar: calendar)
        store.seed(fixture, today: today)
        return store
    }

    /// Applies a fixture to this store, in memory. Idempotent.
    func seed(_ fixture: FixtureState, today: Date) {
        switch fixture {
        case .fresh:
            resetEverything()
        case .premiumActivePlan:
            resetEverything()
            seedPremiumActivePlan(today: today)
        }
    }

    private func seedPremiumActivePlan(today: Date) {
        // Seven consecutive opens ending today: the week row then shows a filled dot for
        // every day up to and including today, which is what `home-dark.png` draws.
        for offset in stride(from: -6, through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            streak.recordOpen(now: day, calendar: calendar)
        }
        touch(.streak)

        // Day 6 of the 30-day plan, five days of it already ticked off, so the card shows
        // both a day label and a part-filled progress bar rather than a fresh 0 %.
        if let started = calendar.date(byAdding: .day, value: -5, to: today) {
            plan.start(planID: FixtureState.planID, at: started)
            for day in 1 ... 5 {
                plan.complete(day: day)
            }
            touch(.plan)
        }

        // Al-Fatihah plus the three short surahs the fixtures ship study content for:
        // enough for a non-zero "verses read" line without claiming a finished Quran.
        progress.markReadAll(in: SurahSpan(number: 1, startIndex: 0, ayahCount: 7))
        progress.markReadAll(in: SurahSpan(number: 112, startIndex: 6222, ayahCount: 4))
        progress.markReadAll(in: SurahSpan(number: 113, startIndex: 6226, ayahCount: 5))
        progress.markReadAll(in: SurahSpan(number: 114, startIndex: 6231, ayahCount: 6))
        touch(.progress)

        // A saved ayah, so the Saved row and the library are not empty either.
        library.save(VerseRef(surah: 2, ayah: 255))
        touch(.library)
    }

    private func resetEverything() {
        streak = StreakState()
        progress = ReadProgress()
        library = Library()
        notes = Notes()
        plan = PlanProgress()
        touch(.streak)
        touch(.progress)
        touch(.library)
        touch(.notes)
        touch(.plan)
    }
}

public extension FixtureState {
    /// `Content/plans.json`'s "start here" plan — the one `home-dark.png` has running.
    static let planID = "juz-a-day"
}
