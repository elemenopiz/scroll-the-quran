import Commerce
import DesignSystem
import FeatureDiscover
import FeaturePaywall
import FeatureReader
import SwiftUI

/// The `--screenshot <id>` registry.
///
/// Every id in `Reference/manifest.json`, plus `gallery`, `tabbar` and `widget-gallery`,
/// resolves here to the *real* screen — not a placeholder — so a capture and a UI test walk
/// the same views a finger would. Each feature owns its own half of the mapping
/// (`PaywallScreens.view(forScreenID:)`, `DiscoverScreens.screen(id:anchor:)`,
/// `ReaderView.screen(for:)`); this file is only the switch that reaches them.
///
/// Routes that live inside the tab bar are rendered *in* the tab bar: the reference captures
/// of the reader, Discover and Community all show it, and a page's height depends on it.
@MainActor
public enum ScreenRegistry {
    /// Every id the registry answers to, for the "no route is unroutable" test.
    public static let allIDs: [String] = ScreenID.allCases.map(\.rawValue)

    /// The screen behind a route.
    ///
    /// - Parameters:
    ///   - route: the parsed `--screenshot` argument.
    ///   - env: the composition root.
    ///   - onFinished: what a modal stage (onboarding, paywall, gift) calls when it is done.
    ///     A snapshot run never taps it; `RootView` uses it to advance the state machine.
    @ViewBuilder
    public static func screen(
        for route: ScreenRoute,
        env: AppEnvironment,
        onFinished: @escaping () -> Void = {}
    ) -> some View {
        switch route.screen {
        case .gallery:
            GalleryScreen()
        case .widgetGallery:
            WidgetGalleryProvider.screen()
        case .onboardingHook, .onboardingSignIn, .onboardingSlide1, .onboardingSlide2,
             .onboardingSlide3, .onboardingSlide4, .onboardingReviews:
            OnboardingScreenProvider.screen(id: route.screen.rawValue, env: env, onFinished: onFinished)
        case .paywallTrial, .paywallPlans, .giftClosed, .giftOpen:
            PaywallScreens.view(
                forScreenID: route.screen.rawValue,
                store: env.entitlements,
                offers: env.offers,
                onDismiss: onFinished,
                onPurchased: onFinished
            )
        case .deepStudy:
            TabRoot(env: env, model: deepStudyModel(route: route, env: env), route: route)
        default:
            TabRoot(env: env, route: route)
        }
    }

    /// Deep Study is reached as a full-screen cover over the Discover tab, which is what the
    /// reference capture shows and the path a reader actually takes. The `#anchor` half of
    /// the route scrolls it to a section.
    private static func deepStudyModel(route: ScreenRoute, env: AppEnvironment) -> TabRootModel {
        let key = DiscoverScreens.defaultStudyKey(feed: env.feed, studies: env.studies, today: env.today)
        return TabRootModel(selection: .discover, deepStudyKey: key, deepStudyAnchor: route.anchor)
    }
}

/// The seam onto the widget gallery.
///
/// `--screenshot widget-gallery` renders every `VerseWidget` family side by side, but the
/// widget views are compiled into the widget extension (and, through `Widget/Shared`, into
/// the app) rather than into `AppShell` — an app extension has no business linking the whole
/// shell. The app registers the view at launch; without it the route falls back to a
/// labelled placeholder rather than failing.
@MainActor
public enum WidgetGalleryProvider {
    /// Set by the app target in `ScrollTheQuranApp.init`.
    public static var make: (() -> AnyView)?

    @ViewBuilder
    public static func screen() -> some View {
        if let make {
            make()
        } else {
            PlaceholderScreen(screenID: "widget-gallery", title: "Widgets", systemImage: "rectangle.on.rectangle")
        }
    }
}
