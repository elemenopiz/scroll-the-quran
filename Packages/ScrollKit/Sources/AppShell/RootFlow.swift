import Foundation
import Observation

/// The first-run funnel: onboarding, then the paywall, then the one-time gift offer
/// if the paywall was dismissed, and finally the tab bar.
public enum RootPhase: String, CaseIterable, Sendable {
    case onboarding
    case paywall
    case gift
    case tabs
}

/// Drives `RootPhase`. Deliberately dumb in Phase 1: `FeatureOnboarding`,
/// `FeaturePaywall` and `UserState` take over the decisions in Phase 3.
@MainActor
@Observable
public final class RootFlowModel {
    public private(set) var phase: RootPhase
    public let launch: LaunchOptions

    public init(launch: LaunchOptions = .live, onboardingDone: Bool = false, subscribed: Bool = false) {
        self.launch = launch
        if let screen = launch.screenshot?.screen {
            phase = RootFlowModel.phase(forScreenshot: screen)
        } else if launch.startsOnTabs || subscribed || onboardingDone {
            phase = .tabs
        } else {
            phase = .onboarding
        }
    }

    /// The happy path: each stage hands over to the next.
    public func advance() {
        switch phase {
        case .onboarding: phase = .paywall
        case .paywall: phase = .tabs
        case .gift: phase = .tabs
        case .tabs: break
        }
    }

    /// Jump straight to the tab bar. A deep link (`scrollthequran://verse/2/255`) has to land
    /// on the verse even on a cold launch that would otherwise start in onboarding.
    public func enterTabs() {
        phase = .tabs
    }

    /// Dismissing the paywall without buying earns the one-time discounted offer.
    public func dismissPaywall(seenOneTimeOffer: Bool) {
        phase = seenOneTimeOffer ? .tabs : .gift
    }

    static func phase(forScreenshot screen: ScreenID) -> RootPhase {
        switch screen {
        case .onboardingHook, .onboardingSignIn, .onboardingSlide1, .onboardingSlide2,
             .onboardingSlide3, .onboardingSlide4, .onboardingReviews:
            .onboarding
        case .paywallTrial, .paywallPlans:
            .paywall
        case .giftClosed, .giftOpen:
            .gift
        default:
            .tabs
        }
    }
}
