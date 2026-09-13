import DesignSystem
@testable import FeatureDiscover
import Foundation
@testable import StudyContent
import Testing
import UserState

/// The REFLECTION card's arithmetic, checked against every reflection that ships, with the
/// real registered fonts.
///
/// Same contract as `DiscoverCardLayoutTests`: the card is a constant height, so the pager
/// lands on a reflection exactly as it lands on a study card. Here that means the group —
/// disc, label, saying, attribution — has to fit inside `ReflectionCardLayout.contentHeight`
/// for all 167, at the narrower of the two canvases.
@Suite("Reflection card layout", .serialized)
struct ReflectionCardLayoutTests {
    /// Repo root, walked up from this file: Tests/FeatureDiscoverTests -> Tests -> ScrollKit
    /// -> Packages -> root.
    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        return url
    }()

    private static func corpus() throws -> [Reflection] {
        let loader = DirectoryContentLoader(root: repoRoot.appendingPathComponent("Content", isDirectory: true))
        return try ReflectionStore(loader: loader).items
    }

    /// The capture canvas (iPhone 17 Pro, 402 pt) and the reference canvas beside it. The
    /// narrower one is the harder case and nothing may overflow on it.
    private static let captureWidth = ReflectionCardLayout.quoteWidth(screenWidth: 402)
    private static let referenceWidth = ReflectionCardLayout.quoteWidth(screenWidth: 393)

    // MARK: - The frame

    @Test("A reflection card is exactly a study card's height")
    func sameHeightAsAStudyCard() {
        #expect(ReflectionCardLayout.contentHeight
            == DiscoverCardLayout.cardHeight - 2 * DiscoverMetrics.cardPadding)
        #expect(ReflectionCardLayout.contentHeight > 0)
    }

    @Test("The quote's measure is the card inset by 40 pt a side")
    func quoteMeasure() {
        #expect(Self.captureWidth == 402 - 2 * DiscoverMetrics.cardInset - 2 * ReflectionMetrics.quoteInset)
        // The page hands the card the study card's content width; the two routes agree.
        let fromContent = ReflectionCardLayout.quoteWidth(
            cardContentWidth: DiscoverCardLayout.contentWidth(screenWidth: 402)
        )
        #expect(abs(fromContent - Self.captureWidth) < 0.001)
    }

    // MARK: - The corpus

    @Test("Every shipped reflection fits the card on both canvases")
    func everyReflectionFits() throws {
        for width in [Self.captureWidth, Self.referenceWidth] {
            for reflection in try Self.corpus() {
                let plan = ReflectionCardLayout.quote(for: reflection.text, width: width)
                let group = ReflectionCardLayout.groupHeight(plan)
                #expect(
                    group <= ReflectionCardLayout.contentHeight,
                    "\(reflection.id) needs \(group) pt of a \(ReflectionCardLayout.contentHeight) pt card at width \(width)"
                )
            }
        }
    }

    @Test("The plan never truncates: its line count is the saying's real one")
    func planIsNeverATruncation() throws {
        for reflection in try Self.corpus() {
            let plan = ReflectionCardLayout.quote(for: reflection.text, width: Self.captureWidth)
            let actual = ReflectionCardLayout.lineCount(reflection.text, size: plan.size, width: Self.captureWidth)
            #expect(plan.lines == actual, "\(reflection.id) is planned shorter than it sets")
            #expect(ReflectionMetrics.quoteSizeLadder.contains(plan.size))
        }
    }

    @Test("The ladder is only stepped down when it has to be")
    func ladderStepsDownOnlyWhenNeeded() throws {
        for reflection in try Self.corpus() {
            let plan = ReflectionCardLayout.quote(for: reflection.text, width: Self.captureWidth)
            guard let index = ReflectionMetrics.quoteSizeLadder.firstIndex(of: plan.size), index > 0 else { continue }
            let larger = ReflectionMetrics.quoteSizeLadder[index - 1]
            let atLarger = ReflectionCardLayout.lineCount(reflection.text, size: larger, width: Self.captureWidth)
            #expect(
                atLarger > ReflectionMetrics.quoteLines,
                "\(reflection.id) dropped to \(plan.size) pt but sets in \(atLarger) lines at \(larger)"
            )
        }
    }

    /// The distribution, as `Reference/scores.md` records it. Not an assertion about any one
    /// reflection — a content change may move a saying between sizes — but a floor under the
    /// whole: most of the catalogue must read at the size the card was designed for.
    @Test("Most of the catalogue sets at 26 pt and none of it overflows six lines by much")
    func distribution() throws {
        let plans = try Self.corpus().map {
            ReflectionCardLayout.quote(for: $0.text, width: Self.captureWidth)
        }
        let atTop = plans.filter { $0.size == ReflectionMetrics.quoteSizeLadder[0] }.count
        #expect(atTop >= plans.count / 2, "only \(atTop) of \(plans.count) set at 26 pt")
        // The floor's escape hatch: a saying may take a seventh line rather than be cut,
        // but nothing in the catalogue may need more than the card can hold.
        let worst = plans.map(\.lines).max() ?? 0
        #expect(worst <= ReflectionMetrics.quoteLines + 2, "a reflection sets in \(worst) lines")
    }

    @Test("The quote glyph is nudged down onto the disc's centre, not left on its line box")
    func markGlyphIsOpticallyCentred() {
        let offset = ReflectionCardLayout.markGlyphOffset()
        // `“` is all ink in the upper half of the em, so the correction is downward and a
        // real fraction of the glyph — a zero here means the font did not register.
        #expect(offset > 0.1 * ReflectionMetrics.markGlyphSize)
        #expect(offset < 0.5 * ReflectionMetrics.markGlyphSize)
    }

    // MARK: - The gate

    @Test("Reflections do not count against the day's free cards")
    func reflectionsAreUnmetered() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let now = try #require(formatter.date(from: "2026-09-14 09:00"))

        let studies = (1 ... 12).map { DiscoverItem(key: "\($0):1", themeId: "t") }
        let reflections = ReflectionStore(items: (1 ... 5).map { index in
            Reflection(
                id: "r\(index)",
                text: "Saying \(index).",
                attribution: "Speaker",
                source: Reflection.Source(work: "Work", locator: "\(index)")
            )
        })
        let stream = DiscoverFeed(items: studies, reflections: reflections).feedItems(seed: 257)

        // Page through the day the way `DiscoverView.land(on:)` does.
        var gate = DiscoverGate(day: DayKey(now, in: calendar))
        var blocked: [String] = []
        for item in stream {
            guard let key = item.meteredKey else { continue }
            if !gate.record(key, on: now, calendar: calendar) {
                blocked.append(key)
            }
        }

        #expect(gate.used == DiscoverGate.freeCardsPerDay, "the gate counted something other than study cards")
        #expect(blocked.count == studies.count - DiscoverGate.freeCardsPerDay)
        // Every reflection in the stream is readable even once the study cards are spent.
        for item in stream where item.isReflection {
            #expect(item.meteredKey == nil)
        }
        #expect(stream.filter(\.isReflection).count == studies.count / DiscoverFeed.studyCardsPerReflection)
    }
}

/// The `--screenshot discover-reflection` seam.
///
/// `TabRoot` builds the Discover tab as the bare `"discover"` screen whatever the route
/// says, and the shell is not this module's to edit, so the route is read off the process
/// arguments here — the same seam `--discover-index` uses. That parse is the only thing
/// standing between the route and a capture that frames the wrong card.
@Suite("Reflection route")
struct ReflectionRouteTests {
    @Test("The module answers to the route")
    func moduleHandlesTheRoute() {
        #expect(DiscoverScreens.handles("discover-reflection"))
        #expect(DiscoverScreens.screenIDs.contains("discover-reflection"))
    }

    @Test("Only `--screenshot discover-reflection` turns it on")
    func parsesOnlyItsOwnRoute() {
        #expect(DiscoverLaunchStart.parse(["app", "--screenshot", "discover-reflection"]))
        #expect(DiscoverLaunchStart.parse(["app", "--screenshot", "discover-reflection", "--reset-state"]))
        #expect(DiscoverLaunchStart.parse(["app", "--screenshot", "discover"]) == false)
        #expect(DiscoverLaunchStart.parse(["app", "--screenshot"]) == false)
        #expect(DiscoverLaunchStart.parse(["app", "discover-reflection"]) == false)
        #expect(DiscoverLaunchStart.parse([]) == false)
    }
}
