import Commerce
@testable import AppShell
import Foundation
import QuranData
import Testing

@Test("The four tabs are in reference order with the reference symbols")
func tabsAreInReferenceOrder() {
    #expect(AppTab.allCases.map(\.title) == ["Community", "Discover", "Home", "The Quran"])
    #expect(AppTab.allCases.map(\.systemImage) == ["person.3", "sparkles", "house", "book"])
    #expect(AppTab.home.accessibilityIdentifier == "tab.home")
}

@Test("Unselected tabs draw the outline symbol and selected tabs the filled one")
func tabSymbolsAreOutlineUntilSelected() {
    #expect(AppTab.allCases.map { $0.tabSymbol(selected: false) } == ["person.3", "sparkles", "house", "book"])
    #expect(
        AppTab.allCases.map { $0.tabSymbol(selected: true) }
            == ["person.3.fill", "sparkles", "house.fill", "book.fill"]
    )
    // The unselected name is the one the rest of the app calls `systemImage`.
    for tab in AppTab.allCases {
        #expect(tab.tabSymbol(selected: false) == tab.systemImage)
    }
}

@Test("Screen routes split the anchor off the id")
func screenRoutesSplitAnchors() {
    let anchored = ScreenRoute(rawValue: "deepstudy#apply-it")
    #expect(anchored?.screen == .deepStudy)
    #expect(anchored?.anchor == "apply-it")
    #expect(anchored?.rawValue == "deepstudy#apply-it")
    #expect(ScreenRoute(rawValue: "home#scrolled")?.tab == .home)
    #expect(ScreenRoute(rawValue: "widget-gallery")?.tab == .home)
    #expect(ScreenRoute(rawValue: "reader")?.tab == .quran)
    #expect(ScreenRoute(rawValue: "not-a-screen") == nil)
}

@Test("Launch options read the screenshot flag and the fixed date")
func launchOptionsParseTheEnvironment() {
    let options = LaunchOptions(
        arguments: ["ScrollTheQuran", "--screenshot", "reader"],
        environment: ["SCROLL_FIXED_DATE": "2026-09-14"]
    )
    #expect(options.screenshot?.screen == .reader)
    #expect(options.isSnapshotRun)
    #expect(options.fixedDate != nil)

    let plain = LaunchOptions(arguments: ["ScrollTheQuran"], environment: [:])
    #expect(plain.screenshot == nil)
    #expect(plain.fixedDate == nil)
    #expect(!plain.isSnapshotRun)
}

@Test("Deep links resolve to verses, studies and tabs")
func deepLinksResolve() throws {
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://verse/2/255"))) == .verse(VerseRef(surah: 2, ayah: 255)))
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://study/94/5-6"))) == .study(PassageRef(
        surah: 94,
        start: 5,
        end: 6
    )))
    // `study/<key>` is the form the widget and a shared link use.
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://study/94:5-6"))) == .study(PassageRef(
        surah: 94,
        start: 5,
        end: 6
    )))
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://study/2:255"))) == .study(PassageRef(
        surah: 2,
        start: 255,
        end: 255
    )))
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://study/not-a-key"))) == nil)
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://tab/discover"))) == .tab(.discover))
    #expect(try DeepLink(url: #require(URL(string: "https://example.com/verse/2/255"))) == nil)
    #expect(try DeepLink(url: #require(URL(string: "scrollthequran://verse/2"))) == nil)
}

@MainActor
@Test("The root flow walks onboarding to paywall to tabs, with the gift on dismissal")
func rootFlowAdvances() {
    let flow = RootFlowModel(launch: LaunchOptions())
    #expect(flow.phase == .onboarding)
    flow.advance()
    #expect(flow.phase == .paywall)
    flow.dismissPaywall(seenOneTimeOffer: false)
    #expect(flow.phase == .gift)
    flow.advance()
    #expect(flow.phase == .tabs)

    let returning = RootFlowModel(launch: LaunchOptions(), onboardingDone: true)
    #expect(returning.phase == .tabs)

    let shot = RootFlowModel(launch: LaunchOptions(screenshot: ScreenRoute(screen: .paywallPlans)))
    #expect(shot.phase == .paywall)
}

@MainActor
@Test("The router moves the selected tab and parks the pending reference")
func routerSelectsTabs() throws {
    let model = TabRootModel()
    #expect(model.selection == .home)
    model.selectTab(.community)
    #expect(model.selection == .community)
    model.open(verse: VerseRef(surah: 2, ayah: 255))
    #expect(model.selection == .quran)
    #expect(model.consumePendingVerse() == VerseRef(surah: 2, ayah: 255))
    #expect(model.consumePendingVerse() == nil)
    try model.openDeepStudy(passage: #require(PassageRef(key: "94:5-6")))
    #expect(model.selection == .discover)
    #expect(model.consumePendingStudy()?.key == "94:5-6")
}

@Test("--ui-test and --open-url are parsed, and both start the app on the tabs")
func launchOptionsParseTheTestFlags() {
    let options = LaunchOptions(
        arguments: ["ScrollTheQuran", "--ui-test", "--open-url", "scrollthequran://verse/2/255"],
        environment: [:]
    )
    #expect(options.isUITest)
    #expect(options.openURL?.absoluteString == "scrollthequran://verse/2/255")
    #expect(options.startsOnTabs)
    // A UI test must not talk to StoreKit: the prices on screen have to be the fixture's.
    #expect(options.usesFixtureCommerce)

    let plain = LaunchOptions(arguments: ["ScrollTheQuran"], environment: [:])
    #expect(!plain.isUITest)
    #expect(plain.openURL == nil)
    #expect(!plain.startsOnTabs)
    #expect(!plain.usesFixtureCommerce)

    // A trailing flag with no value must not crash or half-parse.
    let dangling = LaunchOptions(arguments: ["ScrollTheQuran", "--screenshot"], environment: [:])
    #expect(dangling.screenshot == nil)
}

@Test("--purchase-outcome poses the branch the paywall has to speak about")
func launchOptionsParsePurchaseOutcome() {
    for outcome in FixturePurchaseOutcome.allCases {
        let options = LaunchOptions(
            arguments: ["ScrollTheQuran", "--screenshot", "paywall-trial", "--purchase-outcome", outcome.rawValue],
            environment: [:]
        )
        #expect(options.purchaseOutcome == outcome)
    }
    // Absent, unknown, or dangling all mean "the fixture buys successfully".
    #expect(LaunchOptions(arguments: ["ScrollTheQuran"], environment: [:]).purchaseOutcome == nil)
    #expect(
        LaunchOptions(arguments: ["ScrollTheQuran", "--purchase-outcome", "nonsense"], environment: [:])
            .purchaseOutcome == nil
    )
    #expect(
        LaunchOptions(arguments: ["ScrollTheQuran", "--purchase-outcome"], environment: [:])
            .purchaseOutcome == nil
    )
}

@Test("A screenshot run uses fixture commerce")
func screenshotRunsUseFixtureCommerce() {
    let options = LaunchOptions(arguments: ["ScrollTheQuran", "--screenshot", "paywall-trial"], environment: [:])
    #expect(options.usesFixtureCommerce)
    #expect(options.isSnapshotRun)
}

@Test("A funnel run takes the store it is told to take, and only that run remembers purchases")
func funnelRunsChooseTheirCommerceStore() {
    // `--funnel` alone means the real thing: the tests that run from Xcode against the
    // scheme's StoreKit configuration must not be handed a fixture behind their back.
    let live = LaunchOptions(arguments: ["ScrollTheQuran", "--funnel", "paywall"], environment: [:])
    #expect(live.funnelPhase == .paywall)
    #expect(!live.usesFixtureCommerce)
    #expect(!live.fixtureRemembersPurchases)

    // Saying what the store reports can only be answered by the fixture, and a purchase made
    // there has to outlive the process or "buy, relaunch, still unlocked" asserts nothing.
    let fixture = LaunchOptions(arguments: ["ScrollTheQuran", "--funnel", "paywall", "--free"], environment: [:])
    #expect(fixture.usesFixtureCommerce)
    #expect(!fixture.fixtureIsPremium)
    #expect(fixture.fixtureRemembersPurchases)
    #expect(!fixture.startsOnTabs)

    // Outside the funnel nothing is remembered: one UI test's purchase must not unlock the
    // next one's free tier.
    let uiTest = LaunchOptions(arguments: ["ScrollTheQuran", "--ui-test", "--free"], environment: [:])
    #expect(uiTest.usesFixtureCommerce)
    #expect(!uiTest.fixtureRemembersPurchases)
}

@MainActor
@Test("openDeepStudy(key:) parks the unit key, the passage and the Discover tab")
func routerOpensDeepStudyByKey() {
    let model = TabRootModel()
    model.openDeepStudy(key: "94:5-6")
    #expect(model.selection == .discover)
    #expect(model.deepStudyKey == "94:5-6")
    #expect(model.consumePendingStudy()?.key == "94:5-6")

    // Opening a verse dismisses a Deep Study that is still up: the two are different places.
    model.deepStudyKey = "94:5-6"
    model.open(verse: VerseRef(surah: 2, ayah: 255))
    #expect(model.deepStudyKey == nil)
    #expect(model.selection == .quran)
}

@MainActor
@Test("A widget link resolves through handle(_:) the way onOpenURL does")
func widgetLinkRoutesToTheReader() throws {
    let model = TabRootModel()
    let url = try #require(URL(string: "scrollthequran://verse/2/255"))
    let link = try #require(DeepLink(url: url))
    model.handle(link)
    #expect(model.selection == .quran)
    #expect(model.consumePendingVerse() == VerseRef(surah: 2, ayah: 255))
}

@MainActor
@Test("A deep link on a cold launch skips the first-run funnel")
func deepLinkEntersTheTabs() {
    let flow = RootFlowModel(launch: LaunchOptions())
    #expect(flow.phase == .onboarding)
    flow.enterTabs()
    #expect(flow.phase == .tabs)

    let launched = RootFlowModel(
        launch: LaunchOptions(openURL: URL(string: "scrollthequran://verse/2/255"))
    )
    #expect(launched.phase == .tabs)
}

@Test("Every screen id the registry knows is a manifest id, a gallery or the tab bar")
func everyScreenIDIsRoutable() {
    // The registry switches on `ScreenID`, so "resolves to a screen" is a compile-time
    // property; what this guards is the *list* — a new manifest id has to be added here
    // and in `UITests/RoutingTests.swift`, which launches each one for real.
    let ids = Set(ScreenRegistry.allIDs)
    let manifest = [
        "onboarding-hook", "onboarding-signin", "onboarding-slide1", "onboarding-slide2",
        "onboarding-slide3", "onboarding-slide4", "onboarding-reviews",
        "paywall-trial", "paywall-plans", "gift-closed", "gift-open",
        "community", "discover", "deepstudy", "reader", "translation-sheet", "notes-sheet",
        "reader-verse-menu",
        "home", "plans-sheet", "plan-detail", "verse-search",
    ]
    for id in manifest {
        #expect(ids.contains(id), "\(id) is not in the screenshot registry")
    }
    #expect(ids.contains("gallery"))
    #expect(ids.contains("widget-gallery"))
    #expect(ids.contains("tabbar"))
}

@MainActor
@Test("A plan day opens the reader on the first ayah of its first passage")
func routerOpensAPlanDay() {
    let model = TabRootModel()
    model.openReader(refs: ["18:1-10", "36:1-12"])
    #expect(model.selection == .quran)
    #expect(model.consumePendingVerse() == VerseRef(surah: 18, ayah: 1))

    // Nothing parseable in the list is not a reason to move the app anywhere.
    model.selectTab(.home)
    model.openReader(refs: ["not-a-key"])
    #expect(model.selection == .home)
    #expect(model.consumePendingVerse() == nil)
}

@MainActor
@Test("Both feature seams are wired, so no manifest route answers with a placeholder")
func featureSeamsAreWired() {
    #expect(HomeScreenProvider.isWired)
    #expect(HomeScreenProvider.screenIDs == ["home", "plans-sheet", "plan-detail", "verse-search"])
    #expect(OnboardingScreenProvider.isWired)
    #expect(OnboardingScreenProvider.screenIDs.count == 7)
}
