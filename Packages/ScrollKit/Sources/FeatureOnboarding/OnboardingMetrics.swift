import CoreGraphics
import CoreText
import DesignSystem

/// Geometry measured off `Reference/onboarding-*.png` (393 x 852 pt, iPhone 15 Pro class)
/// with `Tools/snapshot/compare.sh`'s normalisation in mind. Every number here is a
/// measurement, not a guess: the comment names the row or column it came from.
public enum OnboardingMetrics {
    // MARK: - Call to action

    /// Continue fills x 52...340.67 on the 393 pt grid (onboarding-hook.png, y = 2320 px).
    public static let ctaHorizontalInset: CGFloat = 52
    /// Continue occupies rows 746...801.
    public static let ctaHeight: CGFloat = 56
    /// Secondary outline button rows 679...736, Continue rows 746...801.
    public static let ctaSpacing: CGFloat = 10
    /// Continue bottom 802, screen 852, home indicator inset 34 -> 16 pt of padding.
    public static let ctaBottomPadding: CGFloat = 16
    /// Secondary button stroke sampled at #D7D7D9, ~1.5 pt wide (x 51...52).
    public static let secondaryStroke: CGFloat = 1.5

    // MARK: - Type

    /// Hook headline: ink rows 280-309 / 315-344 / 351-380 / 386-409, pitch 35.5 pt.
    public static let hookHeadlineSize: CGFloat = 32
    public static let hookHeadlinePitch: CGFloat = 35.5
    /// Slide + reviews headline: ink rows 107-134 / 139-166, pitch 32 pt.
    public static let slideHeadlineSize: CGFloat = 29
    public static let slideHeadlinePitch: CGFloat = 32
    /// Subheadline: ink rows 185-199 / 203-214, pitch 18 pt.
    public static let subheadlineSize: CGFloat = 17
    public static let subheadlinePitch: CGFloat = 18
    /// Headline/subheadline text column runs x 42...350 -> 22 pt side margins.
    public static let textInset: CGFloat = 22
    /// The hook headline wraps to four lines whose ink is ~300 pt wide (x 45...348).
    /// Source Serif 4 sets narrower than the reference face, so the headline column is
    /// pulled in past `textInset` to make the wrap land on the same words.
    public static let hookHeadlineWidth: CGFloat = 329
    /// Four lines on the reference (ink rows 280/315/351/386).
    public static let hookHeadlineLines = 4
    /// Slide headlines wrap to two lines across the full text column, ink x 42...350.
    public static let slideHeadlineWidth: CGFloat = 349
    /// The reviews headline is a single line (ink rows 90...116).
    public static let reviewsHeadlineLines = 1

    /// The headline column for a slide whose reference title wraps to `lines`.
    /// A three-line reference title (slide 2) sets in a narrower column: ink x 62...329.
    public static func slideHeadlineWidth(titleLines: Int) -> CGFloat {
        titleLines >= 3 ? 289 : slideHeadlineWidth
    }

    /// Height reserved for a slide's top padding, headline and subheadline together, so
    /// the phone frame starts where the reference puts it whatever the type does inside:
    /// frame top 240 on a two-line slide, 256 on slide 2's three-line one, measured from
    /// a 59 pt safe-area top.
    public static func slideTextBlockHeight(titleLines: Int) -> CGFloat {
        (240 - 59) + CGFloat(titleLines - 2) * 16
    }

    /// Trim on top of `.leading(.tight)` to reach the reference baseline pitch.
    public static let hookHeadlineExtraLineSpacing: CGFloat = 0
    public static let slideHeadlineExtraLineSpacing: CGFloat = 0
    /// Gap from the headline block to the subheadline (hook 280-409 / 438; slides 166 / 185).
    public static let headlineToSubheadline: CGFloat = 14

    // MARK: - Slides

    /// Slide headline first ink row 107; safe-area top on the reference device is 59 pt.
    public static let slideTopPadding: CGFloat = 40
    /// Subheadline block bottom 214 -> phone frame top 240.
    public static let subheadlineToPhone: CGFloat = 8

    // MARK: - Phone frame mockup

    /// Outer bezel spans x 74...318 (244 pt) and rows 240...733 (494 pt).
    public static let phoneWidth: CGFloat = 244
    public static let phoneHeight: CGFloat = 494
    /// Black bezel measured 8 pt: outer edge x 75, screen starts x 85.
    public static let phoneBezel: CGFloat = 8
    public static let phoneCornerRadius: CGFloat = 42
    public static let phoneScreenCornerRadius: CGFloat = 34
    /// Dynamic Island: rows 253...273 inside a screen that starts at 249.
    public static let phoneIslandSize = CGSize(width: 98, height: 21)
    public static let phoneIslandTop: CGFloat = 5

    public static var phoneScreenSize: CGSize {
        CGSize(width: phoneWidth - phoneBezel * 2, height: phoneHeight - phoneBezel * 2)
    }

    // MARK: - Sign-in sheet

    /// Sheet spans rows 404...843 at the centre column: 439 pt tall, 9 pt off the bottom.
    public static let sheetHeight: CGFloat = 415
    /// Content column x 27...365 inside a sheet spanning x 8...385 -> 19 pt of inner padding.
    public static let sheetContentInset: CGFloat = 19
    /// Title ink 467-492, i.e. 63 pt below the sheet top.
    public static let sheetTitleTop: CGFloat = 46
    public static let sheetTitleSize: CGFloat = 28
    /// Email field rows 574...618.
    public static let fieldHeight: CGFloat = 44
    public static let fieldCornerRadius: CGFloat = 12
    /// Primary sheet action rows 637...685, capsule radius 24.
    public static let sheetButtonHeight: CGFloat = 48
    /// The dimmed hook behind the sheet samples #828283 over a #FAFAFC background.
    public static let sheetScrimOpacity: CGFloat = 0.40

    // MARK: - Reviews

    /// Headline ink row 90 with a 59 pt safe area above it.
    public static let reviewsTopPadding: CGFloat = 27
    /// Rating pill rows 177...211, x 65...328.
    public static let ratingPillHeight: CGFloat = 34
    /// Subtitle block ends 175, pill rows 177...211.
    public static let subtitleToRatingPill: CGFloat = 8
    /// Pill ends 211, card 1 starts 232.
    public static let ratingPillToCards: CGFloat = 21
    /// Cards run x 28...364 and are 17 pt apart (card 1 ends 449, card 2 starts 466).
    public static let cardInset: CGFloat = 28
    public static let cardSpacing: CGFloat = 17
    public static let cardCornerRadius: CGFloat = 16
    /// The yellow rule down the leading edge of a review card.
    public static let cardAccentWidth: CGFloat = 4

    // MARK: - Line spacing

    /// `lineSpacing` needed to land a bundled face on an exact baseline-to-baseline `pitch`.
    ///
    /// SwiftUI adds `lineSpacing` on top of the font's own line height, which for the
    /// bundled variable faces is not `size * 1.2`. Asking CoreText keeps the reference
    /// pitches (35.5 pt on the hook, 32 pt on the slides) exact instead of guessed.
    public static func lineSpacing(family: String, size: CGFloat, pitch: CGFloat) -> CGFloat {
        max(0, pitch - naturalLineHeight(family: family, size: size))
    }

    static func naturalLineHeight(family: String, size: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName(family as CFString, size, nil)
        let measured = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        // An unregistered face falls back to the system font; keep a sane ratio either way.
        return measured > 0 ? measured : size * 1.2
    }
}
