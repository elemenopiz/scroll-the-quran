@testable import FeatureOnboarding
import Testing

@Suite("Onboarding metrics")
struct OnboardingMetricsTests {
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

    @Test("The measured reference geometry is intact")
    func referenceGeometry() {
        // Continue spans x 52...340.67 and rows 746...801 on the 393x852 reference grid.
        #expect(OnboardingMetrics.ctaHorizontalInset == 52)
        #expect(OnboardingMetrics.ctaHeight == 56)
        #expect(OnboardingMetrics.phoneScreenSize.width == 228)
        #expect(OnboardingMetrics.phoneScreenSize.height == 478)
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
