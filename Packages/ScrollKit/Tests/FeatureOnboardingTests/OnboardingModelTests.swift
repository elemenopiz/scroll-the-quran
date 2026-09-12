@testable import FeatureOnboarding
import Foundation
import Testing

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
