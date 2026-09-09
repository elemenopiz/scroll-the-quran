import Foundation

/// Every screen the snapshot harness can route to with `--screenshot <id>`.
/// The raw values match the ids in `Reference/manifest.json`.
public enum ScreenID: String, CaseIterable, Sendable {
    case onboardingHook = "onboarding-hook"
    case onboardingSignIn = "onboarding-signin"
    case onboardingSlide1 = "onboarding-slide1"
    case onboardingSlide2 = "onboarding-slide2"
    case onboardingSlide3 = "onboarding-slide3"
    case onboardingSlide4 = "onboarding-slide4"
    case onboardingReviews = "onboarding-reviews"
    case paywallTrial = "paywall-trial"
    case paywallPlans = "paywall-plans"
    case giftClosed = "gift-closed"
    case giftOpen = "gift-open"
    case community
    case discover
    case deepStudy = "deepstudy"
    case reader
    case translationSheet = "translation-sheet"
    case notesSheet = "notes-sheet"
    case home
    case plansSheet = "plans-sheet"
    case planDetail = "plan-detail"
    case verseSearch = "verse-search"
    case widgetGallery = "widget-gallery"
    /// Not in the manifest: the bare tab bar, used by the Phase 1 layout spec.
    case tabBar = "tabbar"
    /// Not in the manifest: the DesignSystem component gallery.
    case gallery
}

/// A screen id plus the optional `#anchor` that scrolls it to a section, e.g. `deepstudy#apply-it`.
public struct ScreenRoute: Equatable, Sendable {
    public let screen: ScreenID
    public let anchor: String?

    public init(screen: ScreenID, anchor: String? = nil) {
        self.screen = screen
        self.anchor = anchor
    }

    /// Parses `"deepstudy#apply-it"`, `"home#scrolled"`, `"reader"`.
    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let screen = ScreenID(rawValue: String(parts[0])) else { return nil }
        let anchor = parts.count == 2 && !parts[1].isEmpty ? String(parts[1]) : nil
        self.init(screen: screen, anchor: anchor)
    }

    public var rawValue: String {
        anchor.map { "\(screen.rawValue)#\($0)" } ?? screen.rawValue
    }

    /// The tab that owns this screen, when it lives inside the tab bar.
    public var tab: AppTab? {
        switch screen {
        case .community: .community
        case .discover: .discover
        case .home, .plansSheet, .planDetail, .verseSearch: .home
        case .reader, .translationSheet, .notesSheet: .quran
        default: nil
        }
    }
}
