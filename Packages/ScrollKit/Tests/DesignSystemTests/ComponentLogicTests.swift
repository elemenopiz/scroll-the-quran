@testable import DesignSystem
import SwiftUI
import Testing

@Suite("Component logic")
struct ComponentLogicTests {
    @Test("ProgressBar clamps anything a caller can hand it", arguments: [
        (-1.0, 0.0), (0.0, 0.0), (0.008, 0.008), (0.5, 0.5), (1.0, 1.0), (7.0, 1.0),
    ])
    func progressClamps(input: Double, expected: Double) {
        #expect(ProgressBar.clamp(input) == expected)
    }

    @Test("ProgressBar treats a non-finite ratio as empty rather than crashing")
    func progressRejectsNonFinite() {
        #expect(ProgressBar.clamp(.nan) == 0)
        #expect(ProgressBar.clamp(.infinity) == 0)
        #expect(ProgressBar.clamp(-.infinity) == 0)
    }

    @Test("StarRow rounds to the nearest half star")
    func starSymbols() {
        #expect(StarRow.symbols(for: 5) == Array(repeating: "star.fill", count: 5))
        #expect(StarRow.symbols(for: 0) == Array(repeating: "star", count: 5))
        #expect(StarRow.symbols(for: 4.8) == [
            "star.fill", "star.fill", "star.fill", "star.fill", "star.fill",
        ])
        #expect(StarRow.symbols(for: 4.5) == [
            "star.fill", "star.fill", "star.fill", "star.fill", "star.leadinghalf.filled",
        ])
        #expect(StarRow.symbols(for: 3.1) == [
            "star.fill", "star.fill", "star.fill", "star", "star",
        ])
    }

    @Test("StarRow never renders more or fewer than five stars, whatever it is given")
    func starSymbolsAreBounded() {
        for rating in [-3.0, 0.0, 2.5, 5.0, 99.0, Double.nan] {
            #expect(StarRow.symbols(for: rating).count == 5)
        }
    }

    @Test("WheelPicker3 clamps and resizes a stale selection")
    func wheelNormalises() {
        let columns: [WheelPicker3.Column] = [
            .init(id: "a", title: "A", options: ["1", "2", "3"]),
            .init(id: "b", title: "B", options: ["x", "y"]),
            .init(id: "c", title: "C", options: ["AM", "PM"]),
        ]
        #expect(WheelPicker3.normalized([0, 0, 0], for: columns) == [0, 0, 0])
        // Too short: missing columns start at zero.
        #expect(WheelPicker3.normalized([2], for: columns) == [2, 0, 0])
        // Too long: extras are dropped.
        #expect(WheelPicker3.normalized([1, 1, 1, 9, 9], for: columns) == [1, 1, 1])
        // Out of range in both directions.
        #expect(WheelPicker3.normalized([99, -4, 1], for: columns) == [2, 0, 1])
    }

    @Test("WheelPicker3 survives an empty column instead of trapping")
    func wheelHandlesEmptyColumn() {
        let columns: [WheelPicker3.Column] = [
            .init(id: "a", title: "A", options: []),
            .init(id: "b", title: "B", options: ["x"]),
            .init(id: "c", title: "C", options: ["y"]),
        ]
        #expect(WheelPicker3.normalized([5, 5, 5], for: columns) == [0, 0, 0])
    }

    /// `@MainActor` is load-bearing: resolving a *dynamic* `Color(light:dark:)` on
    /// macOS goes through `NSAppearance`, which hops to the main thread. Off the main
    /// actor inside a test process that hop deadlocks the whole run.
    @MainActor
    @Test("Every Deep Study section maps to its own measured tint")
    func sectionTintsAreDistinct() {
        let tints = TintedSectionKind.allCases.map(\.tint.measuredHex)
        #expect(Set(tints).count == TintedSectionKind.allCases.count)
        #expect(TintedSectionKind.allCases.count == 5)
    }

    @Test("Only the quote box is unlabelled; every other section names itself")
    func sectionTitles() {
        #expect(TintedSectionKind.quote.title == nil)
        #expect(TintedSectionKind.quote.systemImage == nil)
        for kind in TintedSectionKind.allCases where kind != .quote {
            #expect(kind.title?.isEmpty == false)
            #expect(kind.systemImage?.isEmpty == false)
        }
    }

    @Test("A verse action swaps to its filled symbol only while it is on")
    func verseActionSymbol() {
        let off = VerseAction(id: "save", systemImage: "bookmark", filledSystemImage: "bookmark.fill", label: "Save") {}
        let on = VerseAction(
            id: "save", systemImage: "bookmark", filledSystemImage: "bookmark.fill",
            label: "Save", isOn: true
        ) {}
        let noFill = VerseAction(id: "share", systemImage: "square.and.arrow.up", label: "Share", isOn: true) {}
        #expect(off.resolvedSystemImage == "bookmark")
        #expect(on.resolvedSystemImage == "bookmark.fill")
        #expect(noFill.resolvedSystemImage == "square.and.arrow.up")
    }

    @Test("PhoneFrame scales a 393 pt screen down to its mockup width")
    func phoneFrameScale() {
        let frame = PhoneFrame(screenWidth: Metrics.phoneScreenWidth) { EmptyView() }
        #expect(abs(frame.contentScale - 222.0 / 393.0) < 0.0001)
    }
}

/// Round-trips a colour back to the hex string `Tools/snapshot/sample-colors.sh` printed.
private extension Color {
    var measuredHex: String {
        let resolved = resolve(in: EnvironmentValues())
        let channel: (Float) -> Int = { Int(($0 * 255).rounded()) }
        return String(
            format: "%02X%02X%02X",
            channel(resolved.red),
            channel(resolved.green),
            channel(resolved.blue)
        )
    }
}
