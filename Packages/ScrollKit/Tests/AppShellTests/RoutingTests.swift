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

@Test("Screen routes split the anchor off the id")
func screenRoutesSplitAnchors() {
    let anchored = ScreenRoute(rawValue: "deepstudy#apply-it")
    #expect(anchored?.screen == .deepStudy)
    #expect(anchored?.anchor == "apply-it")
    #expect(anchored?.rawValue == "deepstudy#apply-it")
    #expect(ScreenRoute(rawValue: "home#scrolled")?.tab == .home)
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
