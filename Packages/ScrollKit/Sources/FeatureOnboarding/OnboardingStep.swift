import Foundation

/// One screen of the funnel, in order. Raw values are the ids in `Reference/manifest.json`
/// and the `--screenshot` routes, so a step and a snapshot id are the same thing.
public enum OnboardingStep: String, CaseIterable, Sendable, Identifiable {
    case hook = "onboarding-hook"
    case slide1 = "onboarding-slide1"
    case slide2 = "onboarding-slide2"
    case slide3 = "onboarding-slide3"
    case slide4 = "onboarding-slide4"
    case reviews = "onboarding-reviews"

    public var id: String {
        rawValue
    }

    /// Position in `allCases`; this is the integer persisted as `onboardingStep`.
    public var index: Int {
        OnboardingStep.allCases.firstIndex(of: self) ?? 0
    }

    public init(index: Int) {
        let all = OnboardingStep.allCases
        self = all[min(max(index, 0), all.count - 1)]
    }

    /// The slide this step shows, if any (slide 1 is index 0 in `content.slides`).
    public var slideIndex: Int? {
        switch self {
        case .slide1: 0
        case .slide2: 1
        case .slide3: 2
        case .slide4: 3
        case .hook, .reviews: nil
        }
    }

    public var next: OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    public var previous: OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }
}
