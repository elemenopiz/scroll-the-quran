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
        titleLines >= 3 ? 320 : slideHeadlineWidth
    }

    /// The reference row a slide's phone frame starts on — the **enclosure's** own top
    /// edge, measured off the reference slides: 238.3 on the two-line ones
    /// (`onboarding-slide3-discover.png` / `-slide4-search.png`) and 254.3 on slide 2's
    /// three-line one. Slide 1 is the reference's own outlier, 9 pt higher again for the
    /// same two-line title; this model follows the pair, as the 240 it replaces did.
    public static func slidePhoneTop(titleLines: Int) -> CGFloat {
        238 + CGFloat(titleLines - 2) * 16
    }

    /// Height reserved for a slide's top padding, headline and subheadline together, so
    /// the phone frame lands on `slidePhoneTop` whatever the type does inside it.
    /// The 5 pt of slack is calibration: the canvas measures the running device's safe
    /// area, which is not exactly the reference device's 759 pt tall.
    public static func slideTextBlockHeight(titleLines: Int) -> CGFloat {
        slidePhoneTop(titleLines: titleLines) - referenceSafeAreaTop + 5
    }

    /// Safe-area top on the reference device (iPhone 15 Pro class).
    public static let referenceSafeAreaTop: CGFloat = 59

    /// Extra `lineSpacing` needed to reach the reference baseline pitch.
    ///
    /// Both are 0 today and cannot be anything else: Source Serif 4 sets a 1.371 em line
    /// height (43.9 pt at 32 pt, measured with CoreText), which is already wider than the
    /// reference's 35.5 pt pitch, and SwiftUI has no negative `lineSpacing`. Computed
    /// rather than written as `0` so swapping the face fixes itself.
    public static var hookHeadlineExtraLineSpacing: CGFloat {
        lineSpacing(family: FontFamily.serif, size: hookHeadlineSize, pitch: hookHeadlinePitch)
    }

    public static var slideHeadlineExtraLineSpacing: CGFloat {
        lineSpacing(family: FontFamily.serif, size: slideHeadlineSize, pitch: slideHeadlinePitch)
    }

    /// Gap from the headline block to the subheadline (hook 280-409 / 438; slides 166 / 185).
    public static let headlineToSubheadline: CGFloat = 14

    // MARK: - Slides

    /// Slide headline first ink row 107; safe-area top on the reference device is 59 pt.
    public static let slideTopPadding: CGFloat = 40

    /// The reference starts a three-line headline higher up the screen: ink row 91 on
    /// slide 2 against 107 on the two-line slides.
    public static func slideTopPadding(titleLines: Int) -> CGFloat {
        slideTopPadding - CGFloat(titleLines - 2) * 8
    }

    /// The slide call to action follows the phone rather than being pinned to the
    /// bottom: enclosure bottom 736 -> Continue top 746 on slides 3 and 4, and enclosure
    /// bottom 752 -> Continue top 762 on the taller slide 2. Both are the reference's own
    /// rows.
    public static let phoneToCallToAction: CGFloat = 10

    // MARK: - Phone frame mockup

    /// The height of the device's **enclosure** on the reference grid.
    ///
    /// This is the only size the frame is given: `PhoneFrameLayout` divides it by the
    /// iPhone 17 Pro's own 891 pt of enclosure and scales every other number —
    /// width, radii, rail, border, buttons — by the result, so the screen window inside
    /// keeps the capture's 402:874 aspect exactly and nothing has to be cropped to fit.
    ///
    /// 498 is the reference's own enclosure height (238.3...736 on the two-line slides,
    /// 254.3...752 on slide 2), so the device's silhouette lands where the reference puts
    /// it. Its *width* cannot also match: the reference's enclosure is 243.3 pt across,
    /// which is a 0.489 : 1 body no iPhone has, because its bezel is more than twice the
    /// thickness the hardware's is. At the device's own 419 : 891 a 498 pt tall enclosure
    /// is 234.2 pt wide — 4.6 pt inside the reference's edge down each side, and 12 pt
    /// more glass top to bottom. That is the accepted deviation in `Reference/scores.md`:
    /// we draw the iPhone the app runs on, not the mockup's fatter stand-in.
    public static let phoneHeight: CGFloat = 498

    /// The soft ground shadow under the device.
    public static let phoneShadowRadius: CGFloat = 24
    public static let phoneShadowOffset: CGFloat = 12
    public static let phoneShadowOpacityLight: CGFloat = 0.22
    public static let phoneShadowOpacityDark: CGFloat = 0.55

    // MARK: - Sign-in sheet

    /// Detent height that lands the sheet's top edge on row 404, where the reference puts
    /// it. Not 439 (the sheet's measured 404...843 span): iOS 26 floats the sheet inside
    /// its own inset, so the detent it is asked for and the height it draws differ. This
    /// is the number that reproduced the capture.
    public static let sheetHeight: CGFloat = 415
    /// Content column x 27...365 inside a sheet spanning x 8...385 -> 19 pt of inner padding.
    public static let sheetContentInset: CGFloat = 19
    /// Title ink 467-492, i.e. 63 pt below the sheet top.
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
