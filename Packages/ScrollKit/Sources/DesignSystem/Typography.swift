import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

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
    ///
    /// Scales with Dynamic Type relative to `.caption`, capped like `body(_:weight:)`.
    static func capsLabel(_ size: CGFloat = 12, relativeTo style: TextStyle = .caption) -> Font {
        .system(size: scaledSize(size, relativeTo: style), weight: .semibold, design: .default)
    }

    /// SF Pro body text: everything that is not a verse and not the paywall.
    ///
    /// Used 119 times across 39 files — settings rows, library rows, buttons, toolbar
    /// labels, notes, Deep Study prose, community copy — so this one function is what
    /// makes nearly the whole app answer Dynamic Type at all (audit A11Y-1).
    static func body(_ size: CGFloat = 15, weight: Weight = .regular, relativeTo style: TextStyle = .body) -> Font {
        .system(size: scaledSize(size, relativeTo: style), weight: weight, design: .default)
    }

    /// `size`, scaled for the reader's Dynamic Type setting and capped at 200 %.
    ///
    /// **Why not `relativeTo:`.** SwiftUI has no `Font.system(size:relativeTo:)` — the
    /// system font is pinned at whatever point size it is handed, and only
    /// `Font.custom(_:size:relativeTo:)` (which needs a *registered family*, so it works
    /// for Source Serif, Poppins and the Quran script but not for SF Pro) scales. The other
    /// documented route, `@ScaledMetric`, is a `DynamicProperty` and cannot be reached from
    /// a static factory. `UIFontMetrics` is what is left, and it returns `size` **unchanged**
    /// at the `.large` content size, so every measured point size in `Reference/` is
    /// untouched and no capture moves.
    ///
    /// **Why the cap.** 200 % is what WCAG 1.4.4 AA asks for, and it is as far as the
    /// reference's fixed row heights (`RowLink`, `ExploreRow`, the notes editor) can stretch
    /// without the layout pass those call sites have never had. `UIFontMetrics` alone would
    /// take 15 pt to 47 pt at AX5. Verse and Deep Study prose are *not* capped here: they
    /// go through `serifBody`/`serifItalic`, which scale all the way.
    static func scaledSize(_ size: CGFloat, relativeTo style: TextStyle) -> CGFloat {
        #if canImport(UIKit)
            capped(UIFontMetrics(forTextStyle: style.uiKit).scaledValue(for: size), base: size)
        #else
            size
        #endif
    }

    /// Never below the design size — a reader on `extraSmall` is not why the reference was
    /// measured — and never more than `uiTextScaleCeiling` of it.
    static func capped(_ scaled: CGFloat, base: CGFloat) -> CGFloat {
        min(max(scaled, base), base * uiTextScaleCeiling)
    }

    /// The 200 % ceiling on UI text. WCAG 1.4.4 AA's requirement, exactly.
    static let uiTextScaleCeiling: CGFloat = 2
}

#if canImport(UIKit)
    extension Font.TextStyle {
        /// The UIKit style `UIFontMetrics` measures against. `.body` for anything SwiftUI
        /// adds that UIKit has no name for, which is the same fallback SwiftUI itself uses.
        var uiKit: UIFont.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title1
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .subheadline: .subheadline
            case .body: .body
            case .callout: .callout
            case .footnote: .footnote
            case .caption: .caption1
            case .caption2: .caption2
            @unknown default: .body
            }
        }
    }

#endif

public extension View {
    /// The uppercase, wide-tracked section label treatment used throughout Deep Study.
    func capsLabelStyle(size: CGFloat = 12, tracking: CGFloat = Tracking.caps) -> some View {
        font(.capsLabel(size))
            .textCase(.uppercase)
            .tracking(tracking)
    }
}
