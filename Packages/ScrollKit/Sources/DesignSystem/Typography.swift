import SwiftUI

/// The bundled families. Registered by `DesignSystem.registerFonts()`; the raw
/// values are the PostScript names inside the font files (`fc-scan`/name ID 6).
public enum FontFamily {
    /// Source Serif 4, variable Roman. Used for verses, headings and the display numerals.
    public static let serif = "SourceSerif4Variable-Roman"
    /// Source Serif 4, variable Italic. Used for the quoted verse on Discover and Deep Study.
    public static let serifItalic = "SourceSerif4Variable-Italic"
    /// KFGQPC Uthmanic Hafs: the Quran script used for the muted Arabic layer.
    /// Free to use, copy and distribute unmodified; see `LICENSE-UthmanicHafs.txt`.
    public static let quran = "KFGQPCHAFSUthmanicScript-Regula"
    /// Poppins, the geometric sans on the paywall and the gift screens.
    public static let geoRegular = "Poppins-Regular"
    public static let geoSemibold = "Poppins-SemiBold"
    public static let geoBold = "Poppins-Bold"
}

public extension Font {
    /// Large serif display type: the verse reference, the streak count, screen titles.
    static func serifDisplay(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .custom(FontFamily.serif, size: size, relativeTo: style)
    }

    /// Serif running text: the Meaning and Deep Study body copy.
    static func serifBody(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .custom(FontFamily.serif, size: size, relativeTo: style)
    }

    /// Serif italic: the quoted ayah.
    static func serifItalic(_ size: CGFloat = 17, relativeTo style: TextStyle = .body) -> Font {
        .custom(FontFamily.serifItalic, size: size, relativeTo: style)
    }

    /// Poppins Bold: the paywall headline.
    static func geoBold(_ size: CGFloat, relativeTo style: TextStyle = .title) -> Font {
        .custom(FontFamily.geoBold, size: size, relativeTo: style)
    }

    /// Poppins SemiBold: paywall row titles and pill labels.
    static func geoSemibold(_ size: CGFloat, relativeTo style: TextStyle = .headline) -> Font {
        .custom(FontFamily.geoSemibold, size: size, relativeTo: style)
    }

    /// Poppins Regular.
    static func geoRegular(_ size: CGFloat, relativeTo style: TextStyle = .body) -> Font {
        .custom(FontFamily.geoRegular, size: size, relativeTo: style)
    }

    /// The muted Arabic layer (CLAUDE.md rule 5). Never the reading text: it sits
    /// above the English at ~58% of its size, in `Color.textTertiary`, right-to-left
    /// and hidden from VoiceOver. Pass the *Arabic* size, not the English one —
    /// `VerseText` does that conversion for you.
    ///
    /// Deliberately *not* `relativeTo:` scaled: the layer is decorative, and letting
    /// Dynamic Type grow it pushes the English verse off the page.
    static func arabicAccent(_ size: CGFloat) -> Font {
        .custom(FontFamily.quran, fixedSize: size)
    }

    /// The wide uppercase section labels (MEANING, DID YOU KNOW, APPLY IT).
    /// Pair with `.tracking(Tracking.caps)` and `.textCase(.uppercase)`.
    static func capsLabel(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// SF Pro body text: everything that is not a verse and not the paywall.
    static func body(_ size: CGFloat = 15, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

public extension View {
    /// The uppercase, wide-tracked section label treatment used throughout Deep Study.
    func capsLabelStyle(size: CGFloat = 12, tracking: CGFloat = Tracking.caps) -> some View {
        font(.capsLabel(size))
            .textCase(.uppercase)
            .tracking(tracking)
    }
}
