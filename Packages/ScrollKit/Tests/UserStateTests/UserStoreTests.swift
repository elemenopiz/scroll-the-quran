import Foundation
import QuranData
import Testing
@testable import UserState

@Suite("UserStore")
@MainActor
struct UserStoreTests {
    private func makeStore(
        _ fileStore: any UserStateFileStore = MemoryUserStateFileStore(),
        calendar: Calendar = Fixture.utc,
        debounce: Duration = .milliseconds(20)
    ) -> UserStore {
        UserStore(fileStore: fileStore, calendar: calendar, debounce: debounce)
    }

    @Test("A fresh store starts at the defaults")
    func freshStoreDefaults() {
        let store = makeStore()
        #expect(store.currentStreak == 0)
        #expect(store.readCount == 0)
        #expect(store.library.isEmpty)
        #expect(store.notes.isEmpty)
        #expect(store.plan.isActive == false)
        #expect(store.translationID == "itani")
        #expect(store.hasPendingSaves == false)
    }

    @Test("Opening the app records the streak and shows it on the week row")
    func recordOpenDrivesTheStreakCard() {
        let store = makeStore()
        #expect(store.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: Fixture.utc)))
        #expect(store.recordOpen(now: Fixture.date(2026, 9, 15, 8, 0, in: Fixture.utc)))
        #expect(store.currentStreak == 2)
        #expect(store.longestStreak == 2)
        #expect(store.currentStreak(asOf: Fixture.date(2026, 9, 15, 20, 0, in: Fixture.utc)) == 2)

        let row = store.weekRow(now: Fixture.date(2026, 9, 15, 20, 0, in: Fixture.utc))
        #expect(row.map(\.isOpened) == [true, true, false, false, false, false, false])
    }

    @Test("Marking verses read updates the Home labels")
    func markReadUpdatesLabels() {
        let store = makeStore()
        store.markRead(VerseRef(surah: 2, ayah: 255), in: .alBaqarah)
        #expect(store.readCount == 1)
        #expect(store.percentReadLabel == "<1%")
        #expect(store.versesReadLabel == "1 of 6,236 verses")

        store.markSurahRead(.alFatiha)
        #expect(store.readCount == 8)
        #expect(store.progress.isComplete(.alFatiha))
    }

    @Test("Saving, liking and noting a verse each land in their own concern")
    func libraryAndNotesMutations() {
        let store = makeStore()
        let verse = VerseRef(surah: 2, ayah: 255)
        #expect(store.toggleSaved(verse))
        #expect(store.isSaved(verse))
        #expect(store.toggleLiked(verse))
        #expect(store.isLiked(verse))
        store.setNote("the greatest verse", for: verse, now: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        #expect(store.note(for: "2:255")?.text == "the greatest verse")
    }

    @Test("Starting a plan sets its current day")
    func planMutations() {
        let store = makeStore()
        store.startPlan("juz-a-day", on: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        #expect(store.planCurrentDay(now: Fixture.date(2026, 9, 16, 9, 0, in: Fixture.utc)) == 3)
        #expect(store.planCurrentDay(now: Fixture.date(2026, 12, 1, 9, 0, in: Fixture.utc), lengthDays: 30) == 30)
        store.completePlanDay(1)
        #expect(store.plan.isCompleted(day: 1))
        store.stopPlan()
        #expect(store.plan.isActive == false)
    }

    @Test("Onboarding, offer and account protocols write through to prefs")
    func featureProtocolsWriteThroughToPrefs() {
        let store = makeStore()
        let onboarding: any OnboardingProgressStore = store
        let offer: any OfferSeenStore = store
        let account: any AccountSink = store

        onboarding.setOnboardingStep(3)
        #expect(store.prefs.onboardingStep == 3)
        onboarding.completeOnboarding()
        #expect(store.prefs.onboardingDone)

        #expect(offer.hasSeenOneTimeOffer == false)
        offer.markOneTimeOfferSeen()
        #expect(store.prefs.seenOneTimeOffer)

        let identity = SpyAccountIdentity()
        account.attachIdentity(identity)
        account.signIn(email: "reader@example.com")
        #expect(account.isSignedIn)
        // Apple only sends the email on the first sign-in; a later nil must not erase it.
        account.signIn(email: nil)
        #expect(store.prefs.accountEmail == "reader@example.com")
        account.signOut()
        #expect(store.prefs.isSignedIn == false)
        #expect(store.prefs.accountEmail == nil)
        // Audit SEC-2/SEC-4: Settings can only reach `UserStore`, so `UserStore` is what has
        // to drop the Keychain half of the account as well as its own flag.
        #expect(identity.signOutCount == 1)

        onboarding.resetOnboarding()
        #expect(store.prefs.onboardingDone == false)
        #expect(store.prefs.onboardingStep == 0)
    }

    @Test("The reader position and widget verse are remembered")
    func readerPositionAndWidgetVerse() {
        let store = makeStore()
        let position: any ReadingPositionStore = store
        position.setReaderPosition(VerseRef(surah: 2, ayah: 282), page: 2)
        #expect(store.lastReaderPosition?.verse == VerseRef(surah: 2, ayah: 282))
        #expect(store.lastReaderPosition?.page == 2)

        store.setWidgetVerse(VerseRef(surah: 1, ayah: 1))
        #expect(store.widgetVerseRef == VerseRef(surah: 1, ayah: 1))
        store.setTranslation("saheeh")
        #expect(store.translationID == "saheeh")
        store.setCharityVote("islamic-relief")
        #expect(store.charityVote == "islamic-relief")
    }

    @Test("Debounced saves coalesce a burst of edits into one write per concern")
    func debouncedSavesCoalesce() async {
        let files = MemoryUserStateFileStore()
        let store = makeStore(files, debounce: .milliseconds(30))
        for step in 1 ... 5 {
            store.setOnboardingStep(step)
        }
        store.setNote("note", for: "2:255", now: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        #expect(files.totalWrites == 0, "nothing is written while the user is still tapping")

        await store.waitForPendingSaves()
        #expect(files.writeCount(.prefs) == 1)
        #expect(files.writeCount(.notes) == 1)
        #expect(files.writeCount(.progress) == 0, "untouched concerns are not rewritten")
        #expect(store.hasPendingSaves == false)
    }

    @Test("A no-op preference edit does not schedule a write")
    func unchangedPrefsDoNotWrite() async {
        let files = MemoryUserStateFileStore()
        let store = makeStore(files)
        store.setTranslation("itani") // already the default
        #expect(store.hasPendingSaves == false)
        await store.waitForPendingSaves()
        #expect(files.totalWrites == 0)
    }

    @Test("save() writes immediately and cancels the pending debounce")
    func saveWritesImmediately() async {
        let files = MemoryUserStateFileStore()
        let store = makeStore(files, debounce: .seconds(30))
        store.markRead(globalIndex: 261)
        store.save()
        #expect(files.writeCount(.progress) == 1)
        #expect(store.hasPendingSaves == false)
        await store.waitForPendingSaves()
        #expect(files.writeCount(.progress) == 1)
    }

    @Test("A second store loads exactly what the first one saved")
    func stateSurvivesRelaunch() throws {
        let directory = TemporaryDirectory()
        let first = try UserStore(directory: directory.url, calendar: Fixture.utc, debounce: .milliseconds(10))
        first.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: Fixture.utc))
        first.markRead(VerseRef(surah: 2, ayah: 255), in: .alBaqarah)
        first.toggleSaved(VerseRef(surah: 94, ayah: 5))
        first.setNote("hello", for: "94:5", now: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        first.startPlan("patience", on: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        first.setTranslation("ruwwad")
        first.save()

        let second = try UserStore(directory: directory.url, calendar: Fixture.utc)
        second.load()
        #expect(second.currentStreak == 1)
        #expect(second.readCount == 1)
        #expect(second.isSaved(VerseRef(surah: 94, ayah: 5)))
        #expect(second.note(for: "94:5")?.text == "hello")
        #expect(second.plan.activePlanID == "patience")
        #expect(second.translationID == "ruwwad")
        #expect(second.unreadableFiles.isEmpty)
        #expect(directory.fileNames.allSatisfy { $0.hasSuffix(".json") }, "no temp files survive a save")
    }

    @Test("Loading sweeps a crash's leftover temp file and keeps the real state")
    func loadIgnoresLeftoverTemporaryFiles() throws {
        let directory = TemporaryDirectory()
        let first = try UserStore(directory: directory.url, calendar: Fixture.utc)
        first.setTranslation("saheeh")
        first.save()
        directory.write("{\"translationId\":\"half", to: ".prefs-ABC123.tmp")

        let second = try UserStore(directory: directory.url, calendar: Fixture.utc)
        second.load()
        #expect(second.translationID == "saheeh")
        #expect(second.unreadableFiles.isEmpty)
        #expect(directory.fileNames == ["prefs.json"])
    }

    @Test("One corrupt file costs only its own concern")
    func corruptFileDoesNotTakeTheOthersWithIt() throws {
        let directory = TemporaryDirectory()
        let first = try UserStore(directory: directory.url, calendar: Fixture.utc)
        first.setTranslation("pickthall")
        first.setNote("kept", for: "2:255", now: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc))
        first.save()
        directory.write("{ this is not json", to: "prefs.json")

        let second = try UserStore(directory: directory.url, calendar: Fixture.utc)
        second.load()
        #expect(second.translationID == "itani", "the broken concern starts over at its defaults")
        #expect(second.unreadableFiles == [.prefs])
        #expect(second.note(for: "2:255")?.text == "kept", "the other concerns are untouched")
    }

    @Test("Deleting the user's data clears memory and disk")
    func deleteAllData() throws {
        let directory = TemporaryDirectory()
        let store = try UserStore(directory: directory.url, calendar: Fixture.utc)
        store.recordOpen(now: Fixture.date(2026, 9, 14, 8, 0, in: Fixture.utc))
        store.markRead(globalIndex: 261)
        store.toggleSaved(VerseRef(surah: 2, ayah: 255))
        store.setTranslation("saheeh")
        store.save()
        #expect(directory.fileNames.isEmpty == false)

        store.deleteAllData()
        #expect(store.currentStreak == 0)
        #expect(store.readCount == 0)
        #expect(store.library.isEmpty)
        #expect(store.translationID == "itani")
        #expect(directory.fileNames.isEmpty)
        #expect(store.hasPendingSaves == false)
    }

    @Test("The store reads the day from its calendar, so a timezone change is picked up")
    func storeUsesItsInjectedCalendar() {
        let store = makeStore(calendar: Fixture.tokyo)
        // 22:00 UTC is already the next day in Tokyo.
        store.recordOpen(now: Fixture.date(2026, 9, 14, 22, 0, in: Fixture.utc))
        #expect(store.streak.lastOpenedDay == DayKey(year: 2026, month: 9, day: 15))

        store.calendar = Fixture.losAngeles
        store.recordOpen(now: Fixture.date(2026, 9, 14, 22, 0, in: Fixture.utc))
        #expect(store.streak.openedDays.sorted().map(\.text) == ["2026-09-14", "2026-09-15"])
    }
}

/// Stands in for `FeatureOnboarding.KeychainAccountSink`, which `UserState` cannot see.
@MainActor
final class SpyAccountIdentity: AccountIdentityStore {
    private(set) var signOutCount = 0

    func signOut() {
        signOutCount += 1
    }
}

/// Audit SEC-1/SEC-2: `prefs.json` is plaintext in the App Group container, so the account it
/// records is a boolean and an address — never the Apple stable user identifier.
@MainActor
@Suite("Account state")
struct UserStoreAccountTests {
    private func makeStore() -> UserStore {
        UserStore(fileStore: MemoryUserStateFileStore(), calendar: Fixture.utc, debounce: .milliseconds(1))
    }

    @Test("Signing in records a flag and an address, and nothing that identifies anyone")
    func signInWritesNoIdentifier() throws {
        let store = makeStore()
        store.signIn(email: "reader@example.com")
        store.saveAll()

        let data = try #require(try store.fileStore.read(.prefs))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""isSignedIn":true"#))
        #expect(!json.contains("accountId"))
        #expect(!json.contains("000000."))
    }

    @Test("A prefs.json from before the split drops the identifier and keeps the sign-in")
    func legacyIdentifierIsMigratedAway() throws {
        let fileStore = MemoryUserStateFileStore()
        let legacy = #"{"translationId":"itani","accountId":"001234.abcdef","accountEmail":"reader@example.com"}"#
        try fileStore.write(Data(legacy.utf8), to: .prefs)

        let store = UserStore(fileStore: fileStore, calendar: Fixture.utc, debounce: .milliseconds(1))
        store.load()
        #expect(store.isSignedIn)
        #expect(store.accountEmail == "reader@example.com")
        #expect(store.prefs.carriesLegacyAccountID)

        // The migration is not only in memory: seeing the old key marks the file dirty, so the
        // identifier leaves the disk on the launch that finds it rather than on some later
        // preference change that may never come.
        #expect(store.hasPendingSaves)
        store.save()
        let raw = try #require(try fileStore.read(.prefs))
        let rewritten = try #require(String(data: raw, encoding: .utf8))
        #expect(!rewritten.contains("accountId"))
        #expect(rewritten.contains(#""isSignedIn":true"#))
    }

    @Test("Deleting everything drops the Keychain identity too")
    func deleteAllDataClearsTheIdentity() {
        let store = makeStore()
        let identity = SpyAccountIdentity()
        store.attachIdentity(identity)
        store.signIn(email: "reader@example.com")
        store.deleteAllData()
        #expect(store.isSignedIn == false)
        #expect(identity.signOutCount == 1)
    }
}
