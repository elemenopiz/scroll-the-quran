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
    public static let textTertiaryReadable = Color.textTertiaryReadable
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
    /// Draws a tab item's symbol as an **outline** when the tab is unselected and
    /// **filled** when it is selected, the way the reference tab bar does
    /// (`home-dark.png`: outline `person.3` and `book`, filled `house.fill`).
    ///
    /// SwiftUI fills every `tabItem` symbol in both states on its own. The usual cure —
    /// `.environment(\.symbolVariants, .none)` on the `TabView` — does not reach the bar
    /// on iOS 26: the icons came back filled with the modifier in place. Applied to the
    /// `Label` inside `tabItem` it does take, so this goes there:
    ///
    /// ```swift
    /// .tabItem {
    ///     Label(tab.title, systemImage: tab.tabSymbol(selected: isSelected))
    ///         .tabSymbolVariant(selected: isSelected)
    /// }
    /// ```
    ///
    /// Pair it with `AppTab.tabSymbol(selected:)`, which names the filled symbol
    /// explicitly: variant resolution normalises the name, so the two agree, and a symbol
    /// with no `.fill` (`sparkles`) is left alone by both.
    func tabSymbolVariant(selected: Bool) -> some View {
        environment(\.symbolVariants, selected ? .fill : .none)
    }
}

public extension View {
    /// Pins the tab bar to a flat colour instead of the system material.
    ///
    /// The reference bar is a solid `#121214` (dark) / `#FFFFFF` (light). With the default
    /// material the scrolling card stack showed through it as a pale panel across the
    /// first two items. `.tabBar` does not exist on macOS, where this package also builds
    /// for `swift test`, so the modifier is a no-op there.
    func opaqueTabBar(_ color: Color = .tabBarBackground) -> some View {
        #if os(iOS)
            return toolbarBackground(color, for: .tabBar)
                .modifier(VisibleTabBarBackground())
        #else
            return self
        #endif
    }
}

#if os(iOS)
    /// `toolbarBackgroundVisibility(_:for:)` is iOS 18; the app deploys to 17, where the
    /// same thing is spelled `toolbarBackground(_:for:)` with a visibility.
    private struct VisibleTabBarBackground: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 18, *) {
                content.toolbarBackgroundVisibility(.visible, for: .tabBar)
            } else {
                content.toolbarBackground(.visible, for: .tabBar)
            }
        }
    }
#endif

#if os(iOS)
    import UIKit

    public extension DesignSystem {
        /// Pins the tab bar to `Color.tabBarBackground` — the reference's flat `#121214` /
        /// `#FFFFFF` — instead of the system material.
        ///
        /// `View.opaqueTabBar()` is the declarative way to ask for this and it is applied
        /// too, but iOS 26 draws the bar through its own material regardless: measured on
        /// `home` in light appearance, the warm plan-cover artwork scrolling behind the bar
        /// tinted the Community and Discover corner by 11 sRGB steps. The appearance proxy
        /// is the only thing the bar honours.
        ///
        /// Idempotent, so calling it from a view initialiser that re-runs costs nothing.
        /// It has to run before UIKit builds the bar, which a `View.init` does and an
        /// `onAppear` does not.
        @MainActor
        static func configureTabBarAppearance() {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.tabBarBackground)
            appearance.shadowColor = UIColor(Color.divider)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
#endif
