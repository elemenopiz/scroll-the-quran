import SwiftUI

/// Namespaced aliases for the design tokens.
///
/// The palette itself lives in `Tokens.swift` as `Color` statics so it reads naturally
/// at the call site (`.foregroundStyle(.textTertiary)`), and the type scale lives on
/// `Font`. Feature briefs spell the same values `Tokens.textTertiary` and
/// `Typography.arabicAccent(...)`, so both spellings resolve to one definition here —
/// there is no second source of truth, only a second name for it.
public enum Tokens {
    // Surfaces
    public static let appBackground = Color.appBackground
    public static let appBackgroundFlat = Color.appBackgroundFlat
    public static let cardBackground = Color.cardBackground
    public static let rowBackground = Color.rowBackground
    public static let sheetBackground = Color.sheetBackground
    public static let tabBarBackground = Color.tabBarBackground
    public static let didYouKnowBackground = Color.didYouKnowBackground
    public static let chipBackground = Color.chipBackground
    public static let crossRefChipBackground = Color.crossRefChipBackground
    public static let progressTrack = Color.progressTrack
    public static let divider = Color.divider

    // Text
    public static let textPrimary = Color.textPrimary
    public static let textSecondary = Color.textSecondary
    public static let textTertiary = Color.textTertiary
    public static let textOnPill = Color.textOnPill

    // Accents
    public static let pillFill = Color.pillFill
    public static let offlineBadge = Color.offlineBadge
    public static let ratingStar = Color.ratingStar
    public static let flameTop = Color.flameTop
    public static let flameBottom = Color.flameBottom
    public static let flame = LinearGradient.flame

    // Deep Study section tints
    public static let sectionQuote = Color.sectionQuote
    public static let sectionBlue = Color.sectionBlue
    public static let sectionBrown = Color.sectionBrown
    public static let sectionGray = Color.sectionGray
    public static let sectionWine = Color.sectionWine
}

/// Namespaced alias for the type scale. See `Tokens` for why both spellings exist.
public enum Typography {
    public static func serifDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .serifDisplay(size, relativeTo: style)
    }

    public static func serifBody(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .serifBody(size, relativeTo: style)
    }

    public static func serifItalic(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .serifItalic(size, relativeTo: style)
    }

    public static func geoBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .geoBold(size, relativeTo: style)
    }

    public static func geoSemibold(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .geoSemibold(size, relativeTo: style)
    }

    public static func geoRegular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .geoRegular(size, relativeTo: style)
    }

    public static func capsLabel(_ size: CGFloat = 12) -> Font {
        .capsLabel(size)
    }

    public static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .body(size, weight: weight)
    }

    /// The muted Arabic layer (CLAUDE.md rule 5). `size` is the *Arabic* point size.
    public static func arabicAccent(_ size: CGFloat) -> Font {
        .arabicAccent(size)
    }
}

// MARK: - Tab bar symbols

public extension View {
    /// Draws unselected tab icons as **outlines**, the way the reference tab bar does.
    ///
    /// SwiftUI's tab bar applies `.fill` to every `tabItem` symbol in both states, so
    /// `home-dark.png`'s outline `person.3` / `book` came out as `person.3.fill` /
    /// `book.fill` — heavier, wider, and the wrong shape. Turning the automatic variant
    /// off gives outlines everywhere; the selected tab then asks for its filled symbol
    /// by name:
    ///
    /// ```swift
    /// TabView(selection: $selection) {
    ///     …
    ///     .tabItem { Label(tab.title, systemImage: tab.tabSymbol(selected: selection == tab)) }
    /// }
    /// .outlineTabSymbols()
    /// ```
    ///
    /// Applied to the `TabView`, not to an individual item: the environment value has
    /// to reach the tab bar itself. The caller supplies the filled name for the selected
    /// tab, because not every symbol has a `.fill` variant (`sparkles` does not) and
    /// `Image(systemName:)` draws nothing at all for a name that does not exist.
    func outlineTabSymbols() -> some View {
        environment(\.symbolVariants, .none)
    }
}
