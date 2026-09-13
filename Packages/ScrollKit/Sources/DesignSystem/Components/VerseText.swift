import SwiftUI

/// The canonical verse block: the muted Arabic Uthmani line above, the English
/// translation below (CLAUDE.md rule 5).
///
/// The Arabic is **decorative context, not reading text**. It is centred, laid out
/// right-to-left, drawn in `Tokens.textTertiary` at `arabicRatio` of the English point
/// size, given relaxed leading (KFGQPC's em box is 1.758 line-heights tall and its
/// pause marks and superscript alefs sit high above the baseline), never truncated,
/// and hidden from VoiceOver — the English carries the label. It is never
/// transliterated and never a tap target.
public struct VerseText: View {
    /// Where the verse is being shown. Sizes are the English point size measured from
    /// the references (see `Components/README.md`); the Arabic derives from it.
    public enum Size: String, CaseIterable, Sendable {
        /// Full-page reader verse (reader-dark: 30 pt line pitch).
        case reader
        /// Discover card quote (discover-dark: 20 pt line pitch).
        case discover
        /// Deep Study quote box (deepstudy-top: 26.7 pt line pitch).
        case deepStudy
        /// Lock/Home-screen widget.
        case widget

        public var english: CGFloat {
            switch self {
            case .reader: 23
            case .discover: 16
            case .deepStudy: 20
            case .widget: 15
            }
        }

        /// ~58% of the English size — the middle of CLAUDE.md's 55–60% band.
        public var arabic: CGFloat {
            english * VerseText.arabicRatio
        }

        /// The size the Arabic is actually drawn at.
        ///
        /// The 58 % ratio is the design intent, but on the small surfaces it lands
        /// below the point where Uthmani script is still readable: the Discover card
        /// asks for 9.3 pt and Deep Study for 11.6 pt, which is where the Phase 4b
        /// sweep found the accent line collapsing into a grey smear on long passages.
        /// `arabicFloor` is a legibility minimum, not a new ratio — `arabic` (and the
        /// 55–60 % band it satisfies) is left alone. The widget keeps the raw ratio:
        /// its canvas has no room for a 13 pt accent above a 15 pt verse.
        public var renderedArabic: CGFloat {
            self == .widget ? arabic : max(arabic, VerseText.arabicFloor)
        }

        /// How many lines the accent may take before it is allowed to elide. The card
        /// surfaces are fixed-height, so a five-line Arabic passage would push the
        /// English off the bottom; the reader page has the whole screen and is
        /// deliberately unbounded.
        public var arabicLineLimit: Int? {
            switch self {
            case .reader: nil
            case .discover: 3
            case .deepStudy: 3
            case .widget: 2
            }
        }

        /// The muted numeral that opens each ayah after the first.
        ///
        /// 55 % of the English, which is the bottom of CLAUDE.md rule 5's band for the
        /// Arabic layer and the same relationship the mushaf uses between a verse and its
        /// number. It was 62 % and wrapped in \u{2329}\u{232A}, which read as a code token
        /// rather than as a verse mark (Phase 4i).
        public var marker: CGFloat {
            english * VerseText.Size.markerRatio
        }

        /// The marker's share of the English point size, as a constant so a block drawn at
        /// an overridden size (the Discover quote at 15 or 14 pt, Phase 4m) keeps the ratio.
        public static let markerRatio: CGFloat = 0.55
        public static let markerRiseRatio: CGFloat = 0.18

        /// How far the marker rides above the baseline: enough to sit with the ascenders
        /// rather than on the line, not so far that it clips the line above.
        public var markerRise: CGFloat {
            english * VerseText.Size.markerRiseRatio
        }
    }

    /// Roman for the reader page, italic for the quoted ayah on Discover and Deep Study.
    public enum Style: Sendable {
        case roman
        case italic
    }

    /// CLAUDE.md rule 5: the Arabic layer is 55–60% of the English point size.
    public static let arabicRatio: CGFloat = 0.58

    /// The smallest the muted Arabic is ever drawn. Below this the Uthmani
    /// diacritics stop resolving at @3x and the line reads as noise.
    public static let arabicFloor: CGFloat = 13

    private let arabic: String?
    private let segments: [VerseSegment]
    private let quoted: Bool
    private let size: Size
    private let style: Style
    private let alignment: TextAlignment
    private let lineLimit: Int?
    private let englishSize: CGFloat?

    public init(
        arabic: String?,
        english: String,
        size: Size = .reader,
        style: Style = .roman,
        alignment: TextAlignment = .center,
        lineLimit: Int? = nil,
        englishSize: CGFloat? = nil
    ) {
        self.init(
            arabic: arabic,
            segments: [VerseSegment(ayah: 0, text: english)],
            size: size,
            style: style,
            alignment: alignment,
            lineLimit: lineLimit,
            englishSize: englishSize
        )
    }

    /// A passage spanning several ayat.
    ///
    /// Joining the ayat with a bare space runs two sentences together
    /// ("…call for help Guide us…"), and appending punctuation the translator did not
    /// write is not ours to do — Itani's ClearQuran is CC BY-**ND**. So the boundary is
    /// marked instead of edited: a small muted ⟨n⟩ in `Tokens.textTertiaryReadable` opens each
    /// ayah after the first, the same mushaf convention the Arabic line uses. The marker
    /// is decorative — VoiceOver reads the ayat joined, without it.
    ///
    /// - Parameter quoted: wrap the whole passage in straight quotes (the Discover and
    ///   Deep Study treatment), applied outside the markers.
    /// - Parameter englishSize: overrides `size.english` for this one block, and with it
    ///   the ayah markers and the gap under the Arabic line. Only the Discover card passes
    ///   it: Phase 4m steps its quote 16 → 15 → 14 pt so a long passage fits the card
    ///   whole rather than eliding. Everywhere else the surface's own size stands.
    public init(
        arabic: String?,
        segments: [VerseSegment],
        size: Size = .reader,
        style: Style = .roman,
        alignment: TextAlignment = .center,
        quoted: Bool = false,
        lineLimit: Int? = nil,
        englishSize: CGFloat? = nil
    ) {
        self.arabic = arabic
        self.segments = segments
        self.quoted = quoted
        self.size = size
        self.style = style
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.englishSize = englishSize
    }

    /// The point size this block is actually drawn at.
    private var pointSize: CGFloat {
        englishSize ?? size.english
    }

    public var body: some View {
        VStack(spacing: pointSize * 0.5) {
            if let arabic, !arabic.isEmpty {
                ArabicAccentText(arabic, size: size.renderedArabic, lineLimit: size.arabicLineLimit)
            }
            Text(attributedEnglish)
                .font(englishFont)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(alignment)
                // A verse is never elided *unless the surface asks for it*: the Discover
                // card's quote slot is a fixed four lines with a tail ellipsis (Phase 4i),
                // every other surface leaves `lineLimit` nil and `fixedSize` makes the
                // block claim the height it needs instead of truncating in a tight container.
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: lineLimit == nil)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(english)
    }

    /// The passage as one string, markers and quotes stripped — what VoiceOver reads.
    private var english: String {
        segments.map(\.text).joined(separator: " ")
    }

    /// The rendered passage: the ayat verbatim, with a muted ⟨n⟩ opening each one
    /// after the first. A single-ayah verse produces exactly the plain string.
    private var attributedEnglish: AttributedString {
        var out = AttributedString()
        let quoted = quoted && !english.isEmpty
        if quoted {
            out += AttributedString("\"")
        }
        for (offset, segment) in segments.enumerated() {
            if offset > 0 {
                // Thin spaces (U+2009): the marker is a mark on the line, not a word.
                out += AttributedString("\u{2009}")
                out += marker(for: segment.ayah)
                out += AttributedString("\u{2009}")
            }
            out += AttributedString(segment.text)
        }
        if quoted {
            out += AttributedString("\"")
        }
        return out
    }

    /// A bare muted numeral, raised toward the ascenders — the mushaf's verse mark, not
    /// the \u{2329}69\u{232A} code token Phase 4b drew.
    private func marker(for ayah: Int) -> AttributedString {
        var marker = AttributedString("\(ayah)")
        marker.font = .body(pointSize * Size.markerRatio, weight: .semibold)
        marker.foregroundColor = .textTertiaryReadable
        marker.baselineOffset = pointSize * Size.markerRiseRatio
        return marker
    }

    private var englishFont: Font {
        switch style {
        case .roman: .serifBody(pointSize)
        case .italic: .serifItalic(pointSize)
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        case .center: .center
        }
    }
}

/// The muted Arabic line on its own, for surfaces that place it themselves
/// (share cards, the Deep Study key-terms list). Same rules as inside `VerseText`.
public struct ArabicAccentText: View {
    private let text: String
    private let size: CGFloat
    private let lineLimit: Int?

    public init(_ text: String, size: CGFloat, lineLimit: Int? = nil) {
        self.text = text
        self.size = size
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Text(text)
            .font(.arabicAccent(size))
            // Relaxed leading: the pause marks (ۖ ۗ ۚ) and superscript alefs stack
            // high, and KFGQPC's line box is already 1.758 em.
            .lineSpacing(size * 0.35)
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
            // A bounded accent keeps a long passage's decorative layer from pushing
            // the English — the reading text — off a fixed-height card.
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: lineLimit == nil)
            .accessibilityHidden(true)
    }
}

/// One ayah of a passage: its number and the translator's text, verbatim.
public struct VerseSegment: Equatable, Sendable, Identifiable {
    public let ayah: Int
    public let text: String

    public init(ayah: Int, text: String) {
        self.ayah = ayah
        self.text = text
    }

    public var id: Int {
        ayah
    }
}

// MARK: - Previews

/// Ayat al-Kursi. Bundled Arabic (`Content/quran/arabic-uthmani.json`) does not exist
/// yet, so the canonical pause-mark test case is inlined here: it carries ۖ (U+06D6),
///  ۗ (U+06D7) and ۚ (U+06DA), all present in the bundled font's cmap.
public enum VersePreviewFixture {
    public static let ayatAlKursiArabic = """
    ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَٰوَٰتِ وَمَا فِى ٱلْأَرْضِ ۗ \
    مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا بِإِذْنِهِۦ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَىْءٍ \
    مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ ۚ وَسِعَ كُرْسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلْأَرْضَ ۖ وَلَا يَـُٔودُهُۥ حِفْظُهُمَا ۚ \
    وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ
    """

    /// Talal Itani, ClearQuran (the bundled default translation).
    public static let ayatAlKursiEnglish = """
    God! There is no god except He, the Living, the Everlasting. Neither slumber \
    overtakes Him, nor sleep. To Him belongs everything in the heavens and everything \
    on earth. Who is he that can intercede with Him except with His permission?
    """

    public static let shortArabic = "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا"
    public static let shortEnglish = "With hardship comes ease"
}

#Preview("VerseText light") {
    VersePreviews().preferredColorScheme(.light)
}

#Preview("VerseText dark") {
    VersePreviews().preferredColorScheme(.dark)
}

private struct VersePreviews: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxxl) {
                ForEach(VerseText.Size.allCases, id: \.self) { size in
                    VStack(spacing: Spacing.sm) {
                        CapsLabel(text: size.rawValue)
                        VerseText(
                            arabic: VersePreviewFixture.shortArabic,
                            english: VersePreviewFixture.shortEnglish,
                            size: size
                        )
                    }
                }
                VerseText(
                    arabic: VersePreviewFixture.ayatAlKursiArabic,
                    english: VersePreviewFixture.ayatAlKursiEnglish,
                    size: .deepStudy,
                    style: .italic
                )
            }
            .padding(Spacing.xl)
        }
        .background(Color.appBackground)
        .task { DesignSystem.registerFonts() }
    }
}
