@testable import DesignSystem
import SwiftUI
import Testing
#if canImport(AppKit)
    import AppKit
#endif

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

/// Audit A11Y-2 (HIGH, WCAG 1.4.3 AA). `Color.textTertiary` measures 3.26:1 on white and
/// 3.19:1 against `chipBackground` on dark. That is right for the decorative, VoiceOver-
/// hidden Arabic layer it was designed for and for glyphs (1.4.11 asks 3:1 of those), and
/// wrong for the ~20 places it was reused for 12–16 pt text a reader has to read.
@Suite("Text contrast")
struct TextContrastTests {
    /// WCAG 2.x relative luminance.
    private func luminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let c = Double(raw) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Every ground the two tokens are ever drawn on, from `Tokens.swift`.
    private let lightGrounds: [UInt32] = [0xFFFFFF, 0xFAFAFC, 0xF5F5F5, 0xF3F3F4]
    private let darkGrounds: [UInt32] = [0x0F0F11, 0x121214, 0x1C1C1E, 0x1E1E20, 0x1E1E23, 0x2A2A2E, 0x303035]

    private let readableLight: UInt32 = 0x6C6C70
    private let readableDark: UInt32 = 0x9A9A9E

    /// Resolve a dynamic token back to the hex it was built from. A `Color(light:dark:)` is
    /// a provider, not a value, so it cannot be compared directly.
    private func resolved(_ color: Color, dark: Bool) -> UInt32? {
        #if canImport(AppKit)
            var hex: UInt32?
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            appearance?.performAsCurrentDrawingAppearance {
                guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                let channel = { (value: CGFloat) in UInt32((value * 255).rounded()) }
                hex = channel(srgb.redComponent) << 16
                    | channel(srgb.greenComponent) << 8
                    | channel(srgb.blueComponent)
            }
            return hex
        #else
            return nil
        #endif
    }

    @Test("The tokens resolve to the pairs the contrast numbers were measured from")
    func tokensResolveToTheMeasuredPairs() throws {
        #expect(resolved(Color.textTertiaryReadable, dark: false) == readableLight)
        #expect(resolved(Color.textTertiaryReadable, dark: true) == readableDark)
        // And the decorative one is untouched — no measured value in `Reference/` moved.
        #expect(resolved(Color.textTertiary, dark: false) == 0x8E8E93)
        #expect(resolved(Color.textTertiary, dark: true) == 0x7D7D7E)
        #expect(resolved(Color.textSecondary, dark: false) == 0x666666)
        #expect(resolved(Color.textSecondary, dark: true) == 0x999999)
    }

    @Test("Readable tertiary text clears 4.5:1 on every ground in the palette")
    func readableTokenPassesAA() {
        for ground in lightGrounds {
            #expect(
                contrast(readableLight, ground) >= 4.5,
                "light #6C6C70 on #\(String(ground, radix: 16)) is \(contrast(readableLight, ground))"
            )
        }
        for ground in darkGrounds {
            #expect(
                contrast(readableDark, ground) >= 4.5,
                "dark #9A9A9E on #\(String(ground, radix: 16)) is \(contrast(readableDark, ground))"
            )
        }
    }

    @Test("The decorative token is still a third step down, and still fails AA for text")
    func decorativeTokenIsWhatTheFindingSaid() {
        // This is the measurement the audit made; it is recorded here so the split is not
        // "fixed" later by quietly darkening the Arabic layer (CLAUDE.md rule 5).
        #expect(contrast(0x8E8E93, 0xFFFFFF) < 4.5)
        #expect(contrast(0x7D7D7E, 0x303035) < 4.5)
        // 1.4.11: fine for the chevrons, glyphs and separators it is left on.
        #expect(contrast(0x8E8E93, 0xFFFFFF) >= 3)
        #expect(contrast(0x7D7D7E, 0x1E1E23) >= 3)
        // And it is genuinely lighter than the readable token, so the hierarchy survives.
        #expect(luminance(0x8E8E93) > luminance(readableLight))
        #expect(luminance(0x9A9A9E) > luminance(0x7D7D7E))
    }

    @Test("textSecondary already passed, and stays where it is")
    func secondaryUnchanged() {
        for ground in lightGrounds { #expect(contrast(0x666666, ground) >= 4.5) }
        for ground in darkGrounds { #expect(contrast(0x999999, ground) >= 4.5) }
    }
}
