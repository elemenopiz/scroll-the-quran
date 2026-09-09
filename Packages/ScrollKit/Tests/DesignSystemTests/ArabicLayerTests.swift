import CoreText
@testable import DesignSystem
import SwiftUI
import Testing

/// The muted Arabic layer is the one thing in this design system that can fail
/// silently: a missing glyph renders as a blank box, and nobody reviewing English
/// copy would notice. These tests pin the font down.
@Suite("Muted Arabic layer")
struct ArabicLayerTests {
    /// Ayat al-Kursi (2:255): the canonical pause-mark test case. It carries
    ///  ۖ U+06D6, ۗ U+06D7 and ۚ U+06DA plus superscript alef and small waw/yeh.
    private var ayatAlKursi: String {
        VersePreviewFixture.ayatAlKursiArabic
    }

    private func quranFont(size: CGFloat = 24) throws -> CTFont {
        DesignSystem.registerFonts()
        let font = CTFontCreateWithName(FontFamily.quran as CFString, size, nil)
        let resolved = CTFontCopyPostScriptName(font) as String
        try #require(
            resolved == FontFamily.quran,
            "CoreText fell back to \(resolved); the bundled Quran face did not register"
        )
        return font
    }

    @Test("The Quran face ships in the bundle next to its licence")
    func quranFaceIsBundled() throws {
        let fonts = try #require(Bundle.module.url(forResource: "Fonts", withExtension: nil))
        let names = Set(DesignSystem.bundledFontURLs.map(\.lastPathComponent))
        #expect(names.contains("UthmanicHafs1Ver18.ttf"))
        #expect(
            FileManager.default.fileExists(
                atPath: fonts.appendingPathComponent("LICENSE-UthmanicHafs.txt").path
            )
        )
    }

    @Test("registerFonts() makes the Quran PostScript name resolvable")
    func quranFaceRegisters() throws {
        _ = try quranFont()
    }

    @Test("Every character of 2:255 has a glyph, pause marks included")
    func ayatAlKursiHasNoMissingGlyphs() throws {
        let font = try quranFont()
        let scalars = Array(Set(ayatAlKursi.unicodeScalars)).filter { $0 != " " }
        var missing: [String] = []
        for scalar in scalars {
            let units = Array(String(scalar).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: units.count)
            let mapped = CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count)
            if !mapped || glyphs.contains(0) {
                missing.append(String(format: "U+%04X", scalar.value))
            }
        }
        #expect(missing.isEmpty, "font has no glyph for \(missing.joined(separator: ", "))")
    }

    /// U+06D6/06D7/06DA are nonspacing marks, so they never form a grapheme cluster of
    /// their own — the fixture has to be searched by scalar, not by `String.contains`.
    @Test(
        "The three pause marks in 2:255 are individually covered",
        arguments: [Unicode.Scalar(0x06D6)!, Unicode.Scalar(0x06D7)!, Unicode.Scalar(0x06DA)!]
    )
    func pauseMarksAreCovered(mark: Unicode.Scalar) throws {
        #expect(
            ayatAlKursi.unicodeScalars.contains(mark),
            "the fixture no longer exercises U+\(String(mark.value, radix: 16, uppercase: true))"
        )
        let font = try quranFont()
        let units = Array(String(mark).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        #expect(CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count))
        #expect(!glyphs.contains(0))
    }

    @Test("The Arabic fixture is script only — never a transliteration (CLAUDE.md rule 5)")
    func fixtureIsArabicScript() {
        let latin = ayatAlKursi.unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.isASCII }
        #expect(latin.isEmpty)
    }

    @Test("Arabic sits at 55–60% of the English size on every surface")
    func arabicRatioIsInBand() {
        #expect(VerseText.arabicRatio == 0.58)
        for size in VerseText.Size.allCases {
            let ratio = size.arabic / size.english
            #expect(ratio >= 0.55 && ratio <= 0.60, "\(size.rawValue) is \(ratio) of the English size")
            #expect(size.english > 0)
        }
    }

    @Test("Reader is the largest surface and the widget the smallest")
    func sizeOrderMatchesTheReferences() {
        #expect(VerseText.Size.reader.english > VerseText.Size.deepStudy.english)
        #expect(VerseText.Size.deepStudy.english > VerseText.Size.discover.english)
        #expect(VerseText.Size.discover.english > VerseText.Size.widget.english)
    }
}
