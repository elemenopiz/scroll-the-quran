@testable import FeatureHome
import Foundation
import Testing

@Suite("Home routing")
struct HomeRouteTests {
    @Test("every screen id in the brief resolves to a route")
    func routesResolve() {
        #expect(HomeRoute(rawValue: "home") == .home)
        #expect(HomeRoute(rawValue: "home#scrolled") == .homeScrolled)
        #expect(HomeRoute(rawValue: "plans-sheet") == .plansSheet)
        #expect(HomeRoute(rawValue: "plan-detail") == .planDetail)
        #expect(HomeRoute(rawValue: "verse-search") == .verseSearch)
        #expect(HomeRoute(rawValue: "widget-gallery") == .widgetGallery)
    }

    @Test("routes that belong to other features are not claimed")
    func foreignRoutesAreRejected() {
        for id in ["reader", "discover", "community", "deepstudy", "deepstudy#apply-it", "paywall-trial", ""] {
            #expect(HomeRoute.handles(id) == false, "'\(id)' should not route to Home")
        }
    }

    @Test("the plan-detail route picks the active plan, then the 'start here' one")
    func planDetailPicksAPlan() throws {
        let catalog = try HomeTestContent.catalog()
        let active = HomeView.featuredPlan(in: catalog, activeID: "mercy")
        #expect(active?.id == "mercy")

        let fallback = HomeView.featuredPlan(in: catalog, activeID: nil)
        #expect(fallback?.startHere == true)

        let stale = HomeView.featuredPlan(in: catalog, activeID: "deleted-plan")
        #expect(stale?.id == fallback?.id)

        #expect(HomeView.featuredPlan(in: ReadingPlanCatalog(), activeID: nil) == nil)
    }

    @Test("a catalog with no 'start here' plan still yields one")
    func fallbackWithoutStartHere() {
        let catalog = ReadingPlanCatalog(plans: [
            ReadingPlan(
                id: "only", title: "Only", subtitle: "", section: "",
                bestFor: "", lengthDays: 1, dailyMinutes: 1, about: "",
                schedule: [ReadingPlanDay(day: 1, title: "One", refs: ["1:1"])]
            ),
        ])
        #expect(HomeView.featuredPlan(in: catalog, activeID: nil)?.id == "only")
    }
}
