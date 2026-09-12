@testable import DesignSystem
import SwiftUI
import Testing

@Test("DesignSystem module is linked and identifies itself")
func designSystemModuleIdentifiesItself() {
    #expect(DesignSystem.moduleName == "DesignSystem")
}

@Test("Every OFL face and its licence ships in the module bundle")
func bundledFontsArePresent() throws {
    let names = Set(DesignSystem.bundledFontURLs.map(\.lastPathComponent))
    #expect(names == [
        "SourceSerif4Variable-Roman.ttf",
        "SourceSerif4Variable-Italic.ttf",
        "Poppins-Regular.ttf",
        "Poppins-SemiBold.ttf",
        "Poppins-Bold.ttf",
        "UthmanicHafs1Ver18.ttf",
    ])
    let fonts = Bundle.module.url(forResource: "Fonts", withExtension: nil)
    #expect(fonts != nil)
    for licence in ["LICENSE-SourceSerif4.md", "LICENSE-Poppins.txt", "LICENSE-UthmanicHafs.txt"] {
        #expect(try FileManager.default.fileExists(atPath: #require(fonts?.appendingPathComponent(licence).path)))
    }
}

@Test("Font registration is idempotent")
func fontRegistrationIsIdempotent() {
    let first = DesignSystem.registerFonts()
    let second = DesignSystem.registerFonts()
    #expect(first == second)
    #expect(first.count <= DesignSystem.bundledFontURLs.count)
}

@Test("Typography names match the PostScript names inside the font files")
func typographyUsesPostScriptNames() {
    #expect(FontFamily.serif == "SourceSerif4Variable-Roman")
    #expect(FontFamily.serifItalic == "SourceSerif4Variable-Italic")
    #expect(FontFamily.geoBold == "Poppins-Bold")
    #expect(FontFamily.geoSemibold == "Poppins-SemiBold")
    #expect(FontFamily.geoRegular == "Poppins-Regular")
    #expect(FontFamily.quran == "KFGQPCHAFSUthmanicScript-Regula")
}

@Test("Geometry tokens match the reference measurements")
func geometryTokensAreStable() {
    #expect(Radius.pill == 999)
    #expect([Radius.cardSmall, Radius.card, Radius.cardLarge] == [24, 28, 32])
    #expect(Spacing.pageMargin == 16)
    #expect(Tracking.caps == 1.4)
}

@Test("Measured colours resolve to the hex sampled from the references")
func measuredColoursResolve() {
    #expect(Color(rgb: 0x30D158).measuredHex == "30D158")
    #expect(Color.offlineBadge.measuredHex == "30D158")
    #expect(Color.ratingStar.measuredHex == "FFC733")
    #expect(Color.flameTop.measuredHex == "FD8D32")
    #expect(Color.flameBottom.measuredHex == "E7533D")
}

private extension Color {
    /// Round-trips the colour back to the hex string the probe script printed.
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

/// Audit A11Y-1 (CRITICAL, WCAG 1.4.4 AA). `Font.body` and `Font.capsLabel` were
/// `.system(size:)` with no scaling, so a reader on a larger Dynamic Type setting saw **no
/// change** to settings rows, library rows, buttons, toolbar labels, notes, Deep Study
/// prose or community copy — 119 call sites across 39 files.
///
/// The scaling itself is `UIFontMetrics`, which only exists on the device; what can be
/// asserted on the host is the contract around it, which is where the bugs would be.
@Suite("UI text scaling")
struct UITextScalingTests {
    @Test("The design size is what the reference was measured at, and the floor")
    func neverSmallerThanTheDesignSize() {
        // `Reference/` was captured at the `large` content size. A reader on `extraSmall`
        // must not shrink a 393x852 composition out from under its measured metrics.
        #expect(Font.capped(15, base: 15) == 15)
        #expect(Font.capped(13, base: 15) == 15)
        #expect(Font.capped(14.2, base: 15) == 15)
    }

    @Test("UI text grows to 200 % and stops there")
    func ceilingIsTwoHundredPercent() {
        // WCAG 1.4.4 AA asks for 200 %. Past it the reference's fixed row heights
        // (`RowLink`, `ExploreRow`, the notes editor) have never had a layout pass.
        #expect(Font.uiTextScaleCeiling == 2)
        #expect(Font.capped(30, base: 15) == 30)
        // AX5 takes 15 pt to ~47 pt unclamped.
        #expect(Font.capped(47, base: 15) == 30)
        #expect(Font.capped(22.5, base: 15) == 22.5)
    }

    @Test("At the Large content size nothing moves", arguments: [11.0, 12, 13, 14, 15, 16, 17, 20] as [CGFloat])
    func largeIsIdentity(_ size: CGFloat) {
        // `UIFontMetrics.scaledValue(for:)` returns its argument unchanged at `.large`, so
        // this is the property every snapshot in `Reference/` depends on.
        #expect(Font.capped(size, base: size) == size)
        #expect(Font.scaledSize(size, relativeTo: .body) >= size)
        #expect(Font.scaledSize(size, relativeTo: .body) <= size * Font.uiTextScaleCeiling)
    }

    @Test("Every SwiftUI text style maps to a UIKit metric")
    func styleMappingIsTotal() {
        // A style with no mapping would silently scale against `.body` and drift.
        for style in Font.TextStyle.allCases {
            #expect(Font.scaledSize(17, relativeTo: style) >= 17)
        }
    }

    @Test("The muted Arabic layer is still deliberately fixed")
    func arabicStaysFixed() {
        // CLAUDE.md rule 5 and audit A11Y-6: letting Dynamic Type grow the decorative layer
        // pushes the English verse off the page. `arabicAccent` uses `fixedSize:` on purpose.
        #expect(Font.arabicAccent(20) == Font.custom(FontFamily.quran, fixedSize: 20))
    }
}
