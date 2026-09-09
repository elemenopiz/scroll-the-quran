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
    ])
    let fonts = Bundle.module.url(forResource: "Fonts", withExtension: nil)
    #expect(fonts != nil)
    for licence in ["LICENSE-SourceSerif4.md", "LICENSE-Poppins.txt"] {
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
