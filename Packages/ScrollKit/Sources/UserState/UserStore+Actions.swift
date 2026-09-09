import Foundation
import QuranData

/// The domain surface of `UserStore`: one method per thing the app can do to user state.
/// Each mutates the in-memory value and marks exactly one file dirty, so a swipe through the
/// reader writes `progress.json` and nothing else.
@MainActor
public extension UserStore {
    // MARK: Streak

    /// Records an app open for "now". Returns true when this was the day's first open.
    @discardableResult
    func recordOpen(now: Date = Date()) -> Bool {
        let isNewDay = streak.recordOpen(now: now, calendar: calendar)
        touch(.streak)
        return isNewDay
    }

    var currentStreak: Int {
        streak.current
    }

    var longestStreak: Int {
        streak.longest
    }

    func currentStreak(asOf now: Date = Date()) -> Int {
        streak.currentStreak(asOf: now, calendar: calendar)
    }

    /// Seven Monday-to-Sunday dots for the Home streak card.
    func weekRow(now: Date = Date()) -> [StreakDay] {
        streak.weekRow(now: now, calendar: calendar)
    }

    // MARK: Read progress

    @discardableResult
    func markRead(globalIndex: Int) -> Bool {
        let changed = progress.markRead(globalIndex: globalIndex)
        if changed {
            touch(.progress)
        }
        return changed
    }

    func markRead(_ verse: VerseRef, in span: SurahSpan) {
        if progress.markRead(verse, in: span) {
            touch(.progress)
        }
    }

    func markSurahRead(_ span: SurahSpan) {
        progress.markReadAll(in: span)
        touch(.progress)
    }

    var readCount: Int {
        progress.readCount
    }

    var percentReadLabel: String {
        progress.percentLabel
    }

    var versesReadLabel: String {
        progress.versesReadLabel
    }

    // MARK: Library

    @discardableResult
    func toggleSaved(_ verse: VerseRef) -> Bool {
        let saved = library.toggleSaved(verse)
        touch(.library)
        return saved
    }

    @discardableResult
    func toggleSaved(_ passage: PassageRef) -> Bool {
        let saved = library.toggleSaved(passage)
        touch(.library)
        return saved
    }

    @discardableResult
    func toggleLiked(_ verse: VerseRef) -> Bool {
        let liked = library.toggleLiked(verse)
        touch(.library)
        return liked
    }

    func isSaved(_ verse: VerseRef) -> Bool {
        library.isSaved(verse)
    }

    func isSaved(_ passage: PassageRef) -> Bool {
        library.isSaved(passage)
    }

    func isLiked(_ verse: VerseRef) -> Bool {
        library.isLiked(verse)
    }

    // MARK: Notes

    func setNote(_ text: String, for key: String, now: Date = Date()) {
        if notes.set(text, for: key, now: now) {
            touch(.notes)
        }
    }

    func setNote(_ text: String, for verse: VerseRef, now: Date = Date()) {
        setNote(text, for: verse.key, now: now)
    }

    func setNote(_ text: String, for passage: PassageRef, now: Date = Date()) {
        setNote(text, for: passage.key, now: now)
    }

    func note(for key: String) -> Note? {
        notes.note(for: key)
    }

    // MARK: Plan

    func startPlan(_ planID: String, on date: Date = Date()) {
        plan.start(planID: planID, at: date)
        touch(.plan)
    }

    func stopPlan() {
        plan.stop()
        touch(.plan)
    }

    func completePlanDay(_ day: Int) {
        if plan.complete(day: day) {
            touch(.plan)
        }
    }

    func planCurrentDay(now: Date = Date()) -> Int? {
        plan.currentDay(now: now, calendar: calendar)
    }

    func planCurrentDay(now: Date = Date(), lengthDays: Int) -> Int? {
        plan.currentDay(now: now, calendar: calendar, lengthDays: lengthDays)
    }

    // MARK: Prefs

    /// Edit any preference in one place; the file is written once for the whole edit.
    func updatePrefs(_ body: (inout Prefs) -> Void) {
        var updated = prefs
        body(&updated)
        guard updated != prefs else { return }
        prefs = updated
        touch(.prefs)
    }

    var translationID: String {
        prefs.translationID
    }

    func setTranslation(_ id: String) {
        updatePrefs { $0.translationID = id }
    }

    func setCharityVote(_ organisationID: String?) {
        updatePrefs { $0.charityVote = organisationID }
    }

    var charityVote: String? {
        prefs.charityVote
    }

    func setWidgetVerse(_ verse: VerseRef?) {
        updatePrefs { $0.widgetVerseRef = verse }
    }

    var widgetVerseRef: VerseRef? {
        prefs.widgetVerseRef
    }

    // MARK: Deleting

    /// Settings' "delete my data": clears memory and disk, both.
    func deleteAllData() {
        streak.reset()
        progress.reset()
        library.reset()
        notes.reset()
        plan.reset()
        prefs = Prefs()
        saveTask?.cancel()
        saveTask = nil
        dirty = []
        try? fileStore.removeAll()
    }
}

// MARK: - Feature-facing protocols

extension UserStore: OnboardingProgressStore {
    public var onboardingStep: Int {
        prefs.onboardingStep
    }

    public var onboardingDone: Bool {
        prefs.onboardingDone
    }

    public func setOnboardingStep(_ step: Int) {
        updatePrefs { $0.onboardingStep = max(0, step) }
    }

    public func completeOnboarding() {
        updatePrefs {
            $0.onboardingDone = true
        }
    }

    public func resetOnboarding() {
        updatePrefs {
            $0.onboardingDone = false
            $0.onboardingStep = 0
        }
    }
}

extension UserStore: OfferSeenStore {
    public var hasSeenOneTimeOffer: Bool {
        prefs.seenOneTimeOffer
    }

    public func markOneTimeOfferSeen() {
        updatePrefs { $0.seenOneTimeOffer = true }
    }
}

extension UserStore: AccountSink {
    public var accountID: String? {
        prefs.accountID
    }

    public var accountEmail: String? {
        prefs.accountEmail
    }

    public var isSignedIn: Bool {
        prefs.isSignedIn
    }

    public func signIn(accountID: String, email: String?) {
        updatePrefs {
            $0.accountID = accountID
            // Apple only hands over the email on the very first sign-in; keep the one we have.
            if let email, !email.isEmpty {
                $0.accountEmail = email
            }
        }
    }

    public func signOut() {
        updatePrefs {
            $0.accountID = nil
            $0.accountEmail = nil
        }
    }
}

extension UserStore: ReadingPositionStore {
    public var lastReaderPosition: ReaderPosition? {
        prefs.lastReaderPosition
    }

    public func setReaderPosition(_ verse: VerseRef, page: Int = 0) {
        updatePrefs { $0.lastReaderPosition = ReaderPosition(verse: verse, page: page, updatedAt: Date()) }
    }
}
