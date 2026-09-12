@testable import FeatureOnboarding
import Foundation
import Testing
import UserState

@MainActor
@Suite("Onboarding model")
struct OnboardingModelTests {
    private func makeModel(
        progress: EphemeralOnboardingProgressStore = EphemeralOnboardingProgressStore(),
        account: EphemeralAccountSink = EphemeralAccountSink(),
        stats: OnboardingStats? = nil
    ) -> OnboardingModel {
        OnboardingModel(content: .sample, stats: stats, progress: progress, account: account)
    }

    @Test("A fresh install starts on the hook")
    func startsOnHook() {
        #expect(makeModel().step == .hook)
    }

    @Test("Advancing walks the funnel and persists each step")
    func advancePersists() {
        let progress = EphemeralOnboardingProgressStore()
        let model = makeModel(progress: progress)
        model.advance()
        #expect(model.step == .slide1)
        #expect(progress.onboardingStep == 1)
        model.advance()
        model.advance()
        #expect(model.step == .slide3)
        #expect(progress.onboardingStep == 3)
    }

    @Test("Relaunching resumes on the persisted step")
    func resumesFromProgress() {
        let progress = EphemeralOnboardingProgressStore(onboardingStep: 3)
        #expect(makeModel(progress: progress).step == .slide3)
    }

    @Test("Advancing past the last screen finishes and marks the funnel done")
    func finishesAtTheEnd() {
        let progress = EphemeralOnboardingProgressStore(onboardingStep: 5)
        let model = makeModel(progress: progress)
        #expect(model.step == .reviews)
        #expect(!model.isFinished)
        model.advance()
        #expect(model.isFinished)
        #expect(progress.onboardingFinished)
    }

    @Test("Going back rewinds and persists")
    func goBackRewinds() {
        let progress = EphemeralOnboardingProgressStore(onboardingStep: 2)
        let model = makeModel(progress: progress)
        model.goBack()
        #expect(model.step == .slide1)
        #expect(progress.onboardingStep == 1)
        model.goBack()
        model.goBack()
        #expect(model.step == .hook)
    }

    @Test("Sign in with Apple stores the user id and moves on")
    func appleSignInStoresUserID() {
        let account = EphemeralAccountSink()
        let model = makeModel(account: account)
        model.showSignIn()
        #expect(model.isShowingSignIn)
        model.signedInWithApple(userID: "001234.abc", email: "a@b.com", fullName: nil)
        #expect(account.appleUserID == "001234.abc")
        #expect(account.email == "a@b.com")
        #expect(!model.isShowingSignIn)
        #expect(model.step == .slide1)
    }

    @Test("Dismissing the sheet stores whatever was typed, locally")
    func dismissStoresEmail() {
        let account = EphemeralAccountSink()
        let model = makeModel(account: account)
        model.email = "  reader@example.com "
        model.dismissSignIn()
        model.sheetDismissed()
        #expect(account.email == "reader@example.com")
        #expect(!model.isShowingSignIn)
    }

    @Test("Signing in with Apple and then closing the sheet keeps the Apple address")
    func appleEmailSurvivesSheetDismissal() {
        let account = EphemeralAccountSink()
        let model = makeModel(account: account)
        model.showSignIn()
        model.signedInWithApple(userID: "001234.abc", email: "apple@privaterelay.appleid.com", fullName: nil)
        model.sheetDismissed()
        #expect(account.email == "apple@privaterelay.appleid.com")
    }

    @Test("A content file with fewer slides than steps never strands the funnel")
    func shortSlideListIsSkipped() {
        var content = OnboardingContent.sample
        content = OnboardingContent(
            version: content.version, hook: content.hook, signIn: content.signIn,
            slides: Array(content.slides.prefix(2)), reviews: content.reviews, legal: content.legal
        )
        let progress = EphemeralOnboardingProgressStore(onboardingStep: 4)
        let model = OnboardingModel(content: content, progress: progress)
        #expect(model.step != .slide4)
        model.advance()
        model.advance()
        #expect(model.isFinished)
    }

    @Test("An empty field stores nothing")
    func emptyEmailStoresNothing() {
        let account = EphemeralAccountSink()
        let model = makeModel(account: account)
        model.email = "   "
        model.sheetDismissed()
        #expect(account.email == nil)
    }

    @Test("With no real stats the reviews screen drops the count and hides the pill")
    func reviewsWithoutStatsAreHonest() {
        let model = makeModel()
        #expect(model.reviewsSubtitle == OnboardingContent.sample.reviews.subtitleWithoutCount)
        #expect(!model.reviewsSubtitle.contains("{{"))
        #expect(model.reviewsRatingValue == nil)
        #expect(model.reviewsRatingCount == nil)
    }

    @Test("Injected stats are substituted into the subtitle")
    func reviewsWithStats() {
        let model = makeModel(stats: OnboardingStats(installCount: "12,480", reviewCount: "310+", ratingValue: "4.8"))
        #expect(model.reviewsSubtitle == "Join 12,480 Muslims coming back to the Quran.")
        #expect(model.reviewsRatingValue == "4.8")
        #expect(model.reviewsRatingCount == "310+")
    }
}

@Suite("Onboarding stores")
struct OnboardingStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "onboarding.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test("Progress round-trips through UserDefaults")
    func progressRoundTrips() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsOnboardingProgressStore(defaults: defaults)
        #expect(store.onboardingStep == 0)
        #expect(!store.onboardingFinished)
        store.onboardingStep = 4
        store.onboardingFinished = true
        #expect(UserDefaultsOnboardingProgressStore(defaults: defaults).onboardingStep == 4)
        #expect(UserDefaultsOnboardingProgressStore(defaults: defaults).onboardingFinished)
    }

    @Test("The account sink writes the Apple user id under accountId")
    func accountSinkStoresAppleID() throws {
        let defaults = try makeDefaults()
        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: defaults)
        sink.signedInWithApple(userID: "001234.abc", email: nil, fullName: nil)
        #expect(keychain.string(forKey: KeychainAccountSink.accountIDKey) == "001234.abc")
        #expect(sink.appleUserID == "001234.abc")
        // And not in the clear, which is the whole point of audit SEC-1.
        #expect(defaults.string(forKey: KeychainAccountSink.accountIDKey) == nil)
    }

    @Test("A blank field is a no-op; clearing the email is explicit")
    func accountSinkClearsEmail() throws {
        let defaults = try makeDefaults()
        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: defaults)
        sink.storeEmail("reader@example.com")
        #expect(sink.email == "reader@example.com")
        sink.storeEmail("  ")
        #expect(sink.email == "reader@example.com")
        sink.clearEmail()
        #expect(sink.email == nil)
    }
}

/// Audit SEC-1 and SEC-4. The Apple stable user identifier, the email and the formatted
/// full name were three plaintext `UserDefaults` strings, sitting in the app's plist and
/// therefore in unencrypted backups.
@Suite("Keychain account sink")
struct KeychainAccountSinkTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "onboarding.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Everything Apple hands over lands in the keychain, and nothing in the plist")
    func writesGoToTheKeychain() throws {
        let defaults = try makeDefaults()
        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: defaults)

        var name = PersonNameComponents()
        name.givenName = "Amina"
        name.familyName = "Rahman"
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: name)

        #expect(sink.appleUserID == "001234.abc")
        #expect(sink.email == "reader@example.com")
        #expect(sink.displayName == "Amina Rahman")
        for key in [KeychainAccountSink.accountIDKey, KeychainAccountSink.emailKey, KeychainAccountSink.nameKey] {
            #expect(defaults.string(forKey: key) == nil, "\(key) was written in the clear")
        }
    }

    @Test("A second sign-in does not wipe the email and name Apple only sends once")
    func laterSignInKeepsWhatAppleNoLongerSends() throws {
        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: try makeDefaults())
        var name = PersonNameComponents()
        name.givenName = "Amina"
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: name)
        // Apple sends the identifier only from the second sign-in on.
        sink.signedInWithApple(userID: "001234.abc", email: nil, fullName: nil)
        #expect(sink.email == "reader@example.com")
        #expect(sink.displayName == "Amina")
    }

    @Test("An existing install is migrated once and the plaintext keys are deleted")
    func migratesFromUserDefaults() throws {
        let defaults = try makeDefaults()
        defaults.set("001234.abc", forKey: KeychainAccountSink.accountIDKey)
        defaults.set("reader@example.com", forKey: KeychainAccountSink.emailKey)
        defaults.set("Amina Rahman", forKey: KeychainAccountSink.nameKey)

        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: defaults)

        #expect(sink.appleUserID == "001234.abc")
        #expect(sink.email == "reader@example.com")
        #expect(sink.displayName == "Amina Rahman")
        for key in [KeychainAccountSink.accountIDKey, KeychainAccountSink.emailKey, KeychainAccountSink.nameKey] {
            #expect(defaults.string(forKey: key) == nil, "\(key) survived the migration in the clear")
        }
    }

    @Test("The migration never overwrites what the keychain already holds")
    func migrationDoesNotClobber() throws {
        // The keychain survives a delete-and-reinstall and the plist does not, so anything
        // already in the keychain is the newer of the two.
        let defaults = try makeDefaults()
        defaults.set("stale.id", forKey: KeychainAccountSink.accountIDKey)
        let keychain = InMemoryKeychain([KeychainAccountSink.accountIDKey: "current.id"])
        let sink = KeychainAccountSink(keychain: keychain, defaults: defaults)
        #expect(sink.appleUserID == "current.id")
        #expect(defaults.string(forKey: KeychainAccountSink.accountIDKey) == nil)
    }

    @Test("An install that never signed in still has its keys swept")
    func migrationIsIdempotent() throws {
        let defaults = try makeDefaults()
        let keychain = InMemoryKeychain()
        _ = KeychainAccountSink(keychain: keychain, defaults: defaults)
        #expect(keychain.storage.isEmpty)
        // A second construction on the next launch finds nothing and writes nothing.
        _ = KeychainAccountSink(keychain: keychain, defaults: defaults)
        #expect(keychain.storage.isEmpty)
    }

    @Test("Sign-out drops the identifier and the name, not just the email")
    func signOutClearsEverything() throws {
        // Audit SEC-4: `clearEmail()` on the old sink left `accountId` and `accountName`
        // behind, which would have leaked straight through a sign-out.
        let keychain = InMemoryKeychain()
        let sink = KeychainAccountSink(keychain: keychain, defaults: try makeDefaults())
        var name = PersonNameComponents()
        name.givenName = "Amina"
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: name)
        sink.signOut()
        #expect(sink.appleUserID == nil)
        #expect(sink.email == nil)
        #expect(sink.displayName == nil)
        #expect(keychain.storage.isEmpty)
    }

    @Test("The ephemeral sink used by --screenshot still writes nothing at all")
    func fixtureSinkIsUnchanged() {
        let sink = EphemeralAccountSink()
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)
        #expect(sink.appleUserID == "001234.abc")
        sink.signOut()
        #expect(sink.appleUserID == nil)
        #expect(sink.email == nil)
    }
}

/// Audit SEC-2. Onboarding used to write the credential to its own sink and nowhere else, so
/// nothing ever called `UserStore.signIn` and Settings told a reader who had just signed in
/// with Apple that they were not signed in.
@MainActor
@Suite("Composite account sink")
struct CompositeAccountSinkTests {
    /// Stands in for `UserStore`: the same protocol, with the same "a later nil must not wipe
    /// the address" rule, and nowhere for an identifier to go even if one were offered.
    final class StateSpy: UserState.AccountSink {
        var isSignedIn = false
        var accountEmail: String?
        private(set) var identity: (any UserState.AccountIdentityStore)?
        private(set) var signOutCount = 0

        func signIn(email: String?) {
            isSignedIn = true
            if let email, !email.isEmpty {
                accountEmail = email
            }
        }

        func signOut() {
            isSignedIn = false
            accountEmail = nil
            signOutCount += 1
        }

        func attachIdentity(_ identity: any UserState.AccountIdentityStore) {
            self.identity = identity
        }
    }

    private func makeSink() throws -> (CompositeAccountSink, InMemoryKeychain, StateSpy) {
        let suite = "composite.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let keychain = InMemoryKeychain()
        let state = StateSpy()
        let sink = CompositeAccountSink(
            identity: KeychainAccountSink(keychain: keychain, defaults: defaults),
            state: state
        )
        return (sink, keychain, state)
    }

    @Test("The identity goes to the keychain and only a flag and an address to the store")
    func splitsTheCredential() throws {
        let (sink, keychain, state) = try makeSink()
        var name = PersonNameComponents()
        name.givenName = "Amina"
        name.familyName = "Rahman"
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: name)

        #expect(keychain.string(forKey: KeychainAccountSink.accountIDKey) == "001234.abc")
        #expect(keychain.string(forKey: KeychainAccountSink.nameKey) == "Amina Rahman")
        #expect(state.isSignedIn)
        #expect(state.accountEmail == "reader@example.com")
        // The whole of SEC-1: no part of the identifier or the name reaches the store.
        #expect(state.accountEmail != "001234.abc")
    }

    @Test("A later sign-in still tells the store an address, from the keychain")
    func laterSignInStillHasAnAddress() throws {
        let (sink, _, state) = try makeSink()
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)
        state.accountEmail = nil
        // Apple sends the address on the first sign-in only; the keychain is then the only
        // thing that still knows it.
        sink.signedInWithApple(userID: "001234.abc", email: nil, fullName: nil)
        #expect(state.accountEmail == "reader@example.com")
    }

    @Test("Skipping Apple and typing an address is not a sign-in")
    func typedAddressIsNotASignIn() throws {
        let (sink, keychain, state) = try makeSink()
        sink.storeEmail("reader@example.com")
        #expect(keychain.string(forKey: KeychainAccountSink.emailKey) == "reader@example.com")
        // There is no account to be signed into — no network, no server (`CLAUDE.md` rule 9).
        #expect(state.isSignedIn == false)
        #expect(state.accountEmail == nil)
    }

    @Test("Sign-out clears both sides")
    func signOutClearsBothSides() throws {
        let (sink, keychain, state) = try makeSink()
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)
        sink.signOut()
        #expect(keychain.storage.isEmpty)
        #expect(state.isSignedIn == false)
        #expect(state.accountEmail == nil)
    }

    @Test("Building the sink hands the store the keychain record, for Settings' sign-out")
    func attachesTheIdentityToTheStore() throws {
        let (sink, keychain, state) = try makeSink()
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)
        // Settings can only see `UserStore`, so signing out there has to reach the keychain
        // through the record attached at construction — not through the composite.
        let identity = try #require(state.identity)
        identity.signOut()
        #expect(keychain.storage.isEmpty)
    }

    @Test("The fixture sign-in goes through the same path the real credential does")
    func fixtureSignInIsTheRealPath() throws {
        let (sink, keychain, state) = try makeSink()
        sink.applyFixtureSignIn()
        #expect(keychain.string(forKey: KeychainAccountSink.accountIDKey) == CompositeAccountSink.Fixture.userID)
        #expect(sink.identity.displayName == "Amina Rahman")
        #expect(state.isSignedIn)
        #expect(state.accountEmail == CompositeAccountSink.Fixture.email)
    }

    @Test("A keychain write survives being read back through a second sink")
    func keychainRoundTrip() throws {
        // The round trip the app makes across a relaunch: one sink writes, the next one
        // constructed over the same keychain reads it back.
        let suite = "composite.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let keychain = InMemoryKeychain()
        KeychainAccountSink(keychain: keychain, defaults: defaults)
            .signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)

        let next = KeychainAccountSink(keychain: keychain, defaults: defaults)
        #expect(next.appleUserID == "001234.abc")
        #expect(next.email == "reader@example.com")
    }
}

/// The Keychain outlives the App Group container, so the account has to survive a
/// reinstall that takes `prefs.json` with it.
@MainActor
@Suite("Account restored from the keychain")
struct CompositeAccountRestoreTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "composite.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("A keychain that already knows the reader signs them back in")
    func adoptsTheStoredIdentity() throws {
        let keychain = InMemoryKeychain([
            KeychainAccountSink.accountIDKey: "001234.abc",
            KeychainAccountSink.emailKey: "reader@example.com",
        ])
        let state = CompositeAccountSinkTests.StateSpy()
        _ = CompositeAccountSink(
            identity: KeychainAccountSink(keychain: keychain, defaults: try makeDefaults()),
            state: state
        )
        #expect(state.isSignedIn)
        #expect(state.accountEmail == "reader@example.com")
    }

    @Test("Signing out is not undone by the next launch")
    func signOutIsNotResurrected() throws {
        let keychain = InMemoryKeychain()
        let state = CompositeAccountSinkTests.StateSpy()
        let defaults = try makeDefaults()
        let sink = CompositeAccountSink(
            identity: KeychainAccountSink(keychain: keychain, defaults: defaults),
            state: state
        )
        sink.signedInWithApple(userID: "001234.abc", email: "reader@example.com", fullName: nil)
        sink.signOut()

        // The next launch builds a fresh composite over the same keychain.
        _ = CompositeAccountSink(
            identity: KeychainAccountSink(keychain: keychain, defaults: defaults),
            state: state
        )
        #expect(state.isSignedIn == false)
    }
}
