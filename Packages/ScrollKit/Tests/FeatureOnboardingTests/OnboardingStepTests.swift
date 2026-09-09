@testable import FeatureOnboarding
import Testing

@Suite("Onboarding steps")
struct OnboardingStepTests {
    @Test("The funnel is hook, four slides, reviews — in that order")
    func orderMatchesTheFunnel() {
        #expect(OnboardingStep.allCases.map(\.rawValue) == [
            "onboarding-hook",
            "onboarding-slide1",
            "onboarding-slide2",
            "onboarding-slide3",
            "onboarding-slide4",
            "onboarding-reviews",
        ])
    }

    @Test("Raw values are the manifest screen ids")
    func rawValuesRoundTrip() {
        for step in OnboardingStep.allCases {
            #expect(OnboardingStep(rawValue: step.rawValue) == step)
        }
    }

    @Test("A persisted index restores the same step", arguments: Array(0 ..< 6))
    func indexRoundTrips(index: Int) {
        #expect(OnboardingStep(index: index).index == index)
    }

    @Test("Out-of-range persisted progress clamps instead of crashing")
    func indexClamps() {
        #expect(OnboardingStep(index: -4) == .hook)
        #expect(OnboardingStep(index: 99) == .reviews)
    }

    @Test("Only the slides map to a slide index")
    func slideIndexes() {
        #expect(OnboardingStep.hook.slideIndex == nil)
        #expect(OnboardingStep.reviews.slideIndex == nil)
        #expect([OnboardingStep.slide1, .slide2, .slide3, .slide4].map(\.slideIndex) == [0, 1, 2, 3])
    }

    @Test("The ends of the funnel have no next/previous")
    func endsAreClosed() {
        #expect(OnboardingStep.hook.previous == nil)
        #expect(OnboardingStep.reviews.next == nil)
        #expect(OnboardingStep.hook.next == .slide1)
        #expect(OnboardingStep.reviews.previous == .slide4)
    }
}
