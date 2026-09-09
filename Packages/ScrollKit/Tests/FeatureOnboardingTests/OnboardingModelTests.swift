@testable import FeatureOnboarding
import Foundation
import Testing

@MainActor
@Suite("Onboarding model")
struct OnboardingModelTests {
    private func makeModel(
        progress: EphemeralOnboardingProgressStore = EphemeralOnboardingProgressStore(),
        account: EphemeralAccountSink = EphemeralAccountSink(),
        stats: OnboardingStats? = nil,
        onFinished: @escaping () -> Void = {}
    ) -> OnboardingModel {
        OnboardingModel(
            content: .sample, stats: stats, progress: progress, account: account, onFinished: onFinished
        )
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
        var finished = 0
        let model = makeModel(progress: progress, onFinished: { finished += 1 })
        #expect(model.step == .reviews)
        model.advance()
        #expect(finished == 1)
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
        #expect(account.email == "reader@example.com")
        #expect(!model.isShowingSignIn)
    }

    @Test("An empty field stores nothing")
    func emptyEmailStoresNothing() {
        let account = EphemeralAccountSink()
        let model = makeModel(account: account)
        model.email = "   "
        model.commitEmail()
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
        let sink = UserDefaultsAccountSink(defaults: defaults)
        sink.signedInWithApple(userID: "001234.abc", email: nil, fullName: nil)
        #expect(defaults.string(forKey: UserDefaultsAccountSink.accountIDKey) == "001234.abc")
    }

    @Test("Clearing the email removes it rather than storing an empty string")
    func accountSinkClearsEmail() throws {
        let defaults = try makeDefaults()
        let sink = UserDefaultsAccountSink(defaults: defaults)
        sink.storeEmail("reader@example.com")
        #expect(defaults.string(forKey: UserDefaultsAccountSink.emailKey) == "reader@example.com")
        sink.storeEmail("  ")
        #expect(defaults.string(forKey: UserDefaultsAccountSink.emailKey) == nil)
    }
}
