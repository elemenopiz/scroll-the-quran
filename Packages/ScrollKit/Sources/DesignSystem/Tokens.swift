import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - Dynamic colours

public extension Color {
    /// A colour that resolves differently in light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
            self = Color(UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
            })
        #elseif canImport(AppKit)
            self = Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(rgb: isDark ? dark : light)
            })
        #else
            self = Color(rgb: light)
        #endif
    }

    /// A colour that resolves differently in light and dark appearance, each with its
    /// own opacity. `darkOpacity: 0` is how a light-only accent stays absent on dark.
    init(light: UInt32, lightOpacity: Double, dark: UInt32, darkOpacity: Double) {
        #if canImport(UIKit)
            self = Color(UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                return UIColor(rgb: isDark ? dark : light)
                    .withAlphaComponent(isDark ? darkOpacity : lightOpacity)
            })
        #elseif canImport(AppKit)
            self = Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(rgb: isDark ? dark : light)
                    .withAlphaComponent(isDark ? darkOpacity : lightOpacity)
            })
        #else
            self = Color(rgb: light).opacity(lightOpacity)
        #endif
    }

    /// A single 0xRRGGBB value, same in both appearances.
    init(rgb: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}

#if canImport(UIKit)
    extension UIColor {
        convenience init(rgb: UInt32) {
            self.init(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#elseif canImport(AppKit)
    extension NSColor {
        convenience init(rgb: UInt32) {
            self.init(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#endif

// MARK: - Palette

/// Every value below was **measured** from `Reference/*.png` by
/// `Tools/snapshot/sample-colors.sh` (probe points in `Tools/snapshot/probes.json`).
/// Never hand-pick a hex here: move the probe and re-run the script.
///
/// The reference app only ships dark captures of Deep Study, so the light halves of
/// the four section tints are derived from the measured dark values (hue and
/// saturation preserved, lightness lifted to 0.955) rather than measured. Every other
/// pair has both halves measured; the source probe is named in the comment.
public extension Color {
    /// Surfaces
    /// bg.light `#FAFAFC` (onboarding-hook) / bg.dark `#0F0F11` (home-dark)
    static let appBackground = Color(light: 0xFAFAFC, dark: 0x0F0F11)
    /// bgWhite.light `#FFFFFF` (paywall-trial) / bgSheet.dark `#121214` (deepstudy-top)
    static let appBackgroundFlat = Color(light: 0xFFFFFF, dark: 0x121214)
    /// card.light `#FFFFFF` (onboarding-reviews) / card.dark `#1E1E23` (home-dark)
    static let cardBackground = Color(light: 0xFFFFFF, dark: 0x1E1E23)
    /// row.light `#F5F5F5` (paywall-plans) / row.dark `#1E1E20` (deepstudy-bottom)
    static let rowBackground = Color(light: 0xF5F5F5, dark: 0x1E1E20)
    /// card.light `#FFFFFF` / sheet.dark `#1C1C1E` (translation-sheet)
    static let sheetBackground = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// tabBar.dark `#121214` (home-dark)
    static let tabBarBackground = Color(light: 0xFFFFFF, dark: 0x121214)
    /// dykBox.dark `#2A2A2E` (discover-dark)
    static let didYouKnowBackground = Color(light: 0xF3F3F4, dark: 0x2A2A2E)
    /// chip.dark `#303035` (discover-dark theme chip)
    static let chipBackground = Color(light: 0xF3F3F4, dark: 0x303035)
    /// crossRefChip.dark `#252529` (discover-dark)
    static let crossRefChipBackground = Color(light: 0xF3F3F4, dark: 0x252529)
    /// progressTrack.dark `#303035` (home-dark)
    static let progressTrack = Color(light: 0xE6E6E6, dark: 0x303035)
    /// divider.light `#E6E6E6` (paywall-plans) / divider.dark `#38383B` (translation-sheet)
    static let divider = Color(light: 0xE6E6E6, dark: 0x38383B)
    /// The hairline that separates a card from the page **in light appearance only**.
    ///
    /// Dark mode needs nothing: `#1E1E23` on `#0F0F11` is a 15-step separation. Light
    /// mode has none — `#FFFFFF` card on `#FAFAFC` page is a 2-step difference, and the
    /// reference relies on a soft ambient shadow our flat fills do not have, so on a
    /// real screen the Home cards dissolve into the page. `#E8E8ED` is the lightest
    /// stroke that survives the sweep's sigma-6 blur without reading as a drawn border,
    /// and it is `.clear` on dark so **no measured dark value changes**.
    static let cardBorder = Color(light: 0xE8E8ED, lightOpacity: 1, dark: 0x000000, darkOpacity: 0)

    /// Text
    /// textPrimary.light `#000000` (onboarding-hook pill) / white on dark
    static let textPrimary = Color(light: 0x000000, dark: 0xFFFFFF)
    /// textTertiary.light `#666666` (paywall-trial) / textSecondary.dark `#999999` (discover-dark)
    static let textSecondary = Color(light: 0x666666, dark: 0x999999)
    /// textSecondary.light `#8E8E93` (onboarding-reviews) / textTertiary.dark `#7D7D7E` (deepstudy-bottom)
    static let textTertiary = Color(light: 0x8E8E93, dark: 0x7D7D7E)
    /// Text drawn on top of `pillFill`.
    static let textOnPill = Color(light: 0xFFFFFF, dark: 0x000000)

    /// Accents
    /// pill.dark `#000000` (paywall-trial Redeem) / pill.light `#FFFFFF` (home-dark Settings)
    static let pillFill = Color(light: 0x000000, dark: 0xFFFFFF)
    /// offlineBadge.green `#30D158` (translation-sheet)
    static let offlineBadge = Color(rgb: 0x30D158)
    /// star.yellow `#FFC733` (onboarding-reviews)
    static let ratingStar = Color(rgb: 0xFFC733)
    /// flame.top `#FD8D32` (home-dark streak)
    static let flameTop = Color(rgb: 0xFD8D32)
    /// flame.bottom `#E7533D` (home-dark streak)
    static let flameBottom = Color(rgb: 0xE7533D)

    /// Deep Study section tints (dark measured, light derived — see the type comment)
    /// quoteBox.dark `#231E19` (deepstudy-top)
    static let sectionQuote = Color(light: 0xF7F4F0, dark: 0x231E19)
    /// sectionBlue.dark `#0F2130` (deepstudy-top, HISTORICAL CONTEXT)
    static let sectionBlue = Color(light: 0xEEF4F9, dark: 0x0F2130)
    /// sectionBrown.dark `#1F1B1B` (deepstudy-mid, LIFE IN THE PROPHET'S TIME)
    static let sectionBrown = Color(light: 0xF5F2F2, dark: 0x1F1B1B)
    /// sectionGray.dark `#1E1E20` (deepstudy-mid, DID YOU KNOW)
    static let sectionGray = Color(light: 0xF3F3F4, dark: 0x1E1E20)
    /// sectionWine.dark `#251618` (deepstudy-bottom, APPLY IT)
    static let sectionWine = Color(light: 0xF8EFF0, dark: 0x251618)
}

/// The streak flame gradient, top to bottom.
public extension LinearGradient {
    static let flame = LinearGradient(
        colors: [.flameTop, .flameBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Geometry

/// Corner radii. `pill` is a large constant rather than `.capsule` so it can be used
/// with `RoundedRectangle` in the same way as the card radii.
public enum Radius {
    public static let pill: CGFloat = 999
    public static let chip: CGFloat = 16
    public static let cardSmall: CGFloat = 24
    public static let card: CGFloat = 28
    public static let cardLarge: CGFloat = 32
}

/// The 4-point spacing scale everything lays out on.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
    public static let huge: CGFloat = 40

    /// Horizontal page inset used by every scrolling screen.
    public static let pageMargin: CGFloat = 16
}

/// Letter spacing. The reference sets its uppercase labels noticeably wide.
public enum Tracking {
    public static let caps: CGFloat = 1.4
    public static let capsTight: CGFloat = 0.8
    public static let display: CGFloat = -0.4
}

/// Stroke widths.
public enum Stroke {
    public static let hairline: CGFloat = 1
    public static let outline: CGFloat = 1.5
}
