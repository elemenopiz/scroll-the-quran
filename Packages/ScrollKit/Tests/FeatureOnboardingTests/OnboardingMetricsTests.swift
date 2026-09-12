import DesignSystem
@testable import FeatureOnboarding
import Testing

@Suite("Onboarding metrics")
struct OnboardingMetricsTests {
    /// Swift Testing builds the suite value once per test, so this is the suite's setup.
    ///
    /// `headlineSpacingIsZero` measures Source Serif 4 through CoreText, which only
    /// answers once the bundled faces are registered. Relying on another suite in the
    /// same process having called `registerFonts()` first made this file order-dependent:
    /// it failed every time under `swift test --filter OnboardingMetricsTests`, and
    /// whenever the scheduler happened to run it first. `registerFonts()` is idempotent
    /// and thread-safe, so calling it here costs nothing.
    init() {
        DesignSystem.registerFonts()
    }

    @Test("Line spacing is the difference between the wanted pitch and the font's line height")
    func lineSpacingHitsThePitch() {
        let family = "Helvetica"
        let natural = OnboardingMetrics.naturalLineHeight(family: family, size: 32)
        let spacing = OnboardingMetrics.lineSpacing(family: family, size: 32, pitch: natural + 4)
        #expect(abs(spacing - 4) < 0.001)
    }

    @Test("A pitch tighter than the font's own line height clamps to zero rather than going negative")
    func lineSpacingNeverNegative() {
        #expect(OnboardingMetrics.lineSpacing(family: "Helvetica", size: 32, pitch: 4) == 0)
    }

    @Test("An unregistered face still reports a usable line height")
    func unknownFamilyFallsBack() {
        #expect(OnboardingMetrics.naturalLineHeight(family: "NotARealFace-Regular", size: 20) > 0)
    }

    @Test("Source Serif 4 already sets wider than the reference pitch, so no extra spacing")
    func headlineSpacingIsZero() {
        // 1.371 em: 43.9 pt at the hook's 32 pt, against a reference pitch of 35.5 pt.
        #expect(OnboardingMetrics.hookHeadlineExtraLineSpacing == 0)
        #expect(OnboardingMetrics.slideHeadlineExtraLineSpacing == 0)
    }

    @Test("A slide's phone frame lands on the reference row for its title's line count")
    func slideGeometryFollowsTitleLines() {
        #expect(OnboardingMetrics.slidePhoneTop(titleLines: 2) == 238)
        #expect(OnboardingMetrics.slidePhoneTop(titleLines: 3) == 254)
        #expect(
            OnboardingMetrics.slideTextBlockHeight(titleLines: 3)
                - OnboardingMetrics.slideTextBlockHeight(titleLines: 2) == 16
        )
        #expect(OnboardingMetrics.slideHeadlineWidth(titleLines: 3) < OnboardingMetrics.slideHeadlineWidth)
    }

    @Test("The measured reference geometry is intact")
    func referenceGeometry() {
        // Continue spans x 52...340.67 and rows 746...801 on the 393x852 reference grid.
        #expect(OnboardingMetrics.ctaHorizontalInset == 52)
        #expect(OnboardingMetrics.ctaHeight == 56)
        #expect(OnboardingMetrics.phoneHeight == 498)
    }
}

@Suite("Snapshot routing")
struct FeatureOnboardingModuleTests {
    @Test("Every funnel screen id has a view behind it")
    @MainActor
    func everyScreenIDResolves() {
        for id in FeatureOnboardingModule.screenIDs {
            #expect(FeatureOnboardingModule.screen(for: id) != nil, "no view for \(id)")
        }
    }

    @Test("The sign-in id is routed, and unknown ids are not")
    @MainActor
    func unknownIDsReturnNil() {
        #expect(FeatureOnboardingModule.screen(for: "onboarding-signin") != nil)
        #expect(FeatureOnboardingModule.screen(for: "paywall-trial") == nil)
        #expect(FeatureOnboardingModule.screen(for: "") == nil)
    }

    @Test("The module still identifies itself")
    func moduleName() {
        #expect(FeatureOnboardingModule.moduleName == "FeatureOnboarding")
    }
}
