@testable import FeatureHome
import Foundation
import Testing

@Suite("Streak dots and read progress")
struct HomePresentationTests {
    @Test("today is ringed whether or not the app has been opened yet")
    func todayIsRinged() {
        #expect(StreakDotStyle.forDay(isOpened: true, isToday: true, isFuture: false) == .today)
        #expect(StreakDotStyle.forDay(isOpened: false, isToday: true, isFuture: false) == .todayPending)
        #expect(StreakDotStyle.today.isRinged)
        #expect(StreakDotStyle.todayPending.isRinged)
        #expect(StreakDotStyle.today.isFilled)
        #expect(StreakDotStyle.todayPending.isFilled == false)
    }

    @Test("a past day is filled only when it was opened; a future day is always an empty well")
    func pastAndFuture() {
        #expect(StreakDotStyle.forDay(isOpened: true, isToday: false, isFuture: false) == .opened)
        #expect(StreakDotStyle.forDay(isOpened: false, isToday: false, isFuture: false) == .empty)
        #expect(StreakDotStyle.forDay(isOpened: false, isToday: false, isFuture: true) == .empty)
        #expect(StreakDotStyle.opened.isFilled)
        #expect(StreakDotStyle.empty.isFilled == false)
        #expect(StreakDotStyle.empty.isRinged == false)
    }

    @Test("the motivational line changes with the streak")
    func motivation() {
        #expect(StreakMotivation.line(forStreak: 0) == "Open the Quran today and your streak starts.")
        #expect(StreakMotivation.line(forStreak: 1) == "Great start. Come back tomorrow to keep it going.")
        #expect(StreakMotivation.line(forStreak: 4) == "4 days in a row. Keep it going.")
        #expect(StreakMotivation.line(forStreak: 7) == "7 days in a row. That is a habit now.")
        #expect(StreakMotivation.line(forStreak: 400) == "400 days in a row. Remarkable.")
    }

    @Test("the progress bar fraction is verses over 6,236, clamped")
    func progressFraction() {
        #expect(ReadProgressSummary(readCount: 0).fraction == 0)
        #expect(ReadProgressSummary(readCount: -5).readCount == 0)
        #expect(ReadProgressSummary(readCount: 6236).fraction == 1)
        #expect(ReadProgressSummary(readCount: 99999).fraction == 1)
        #expect(abs(ReadProgressSummary(readCount: 3118).fraction - 0.5) < 0.0001)
    }
}
