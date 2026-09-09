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
    }

    /// Roman for the reader page, italic for the quoted ayah on Discover and Deep Study.
    public enum Style: Sendable {
        case roman
        case italic
    }

    /// CLAUDE.md rule 5: the Arabic layer is 55–60% of the English point size.
    public static let arabicRatio: CGFloat = 0.58

    private let arabic: String?
    private let english: String
    private let size: Size
    private let style: Style
    private let alignment: TextAlignment

    public init(
        arabic: String?,
        english: String,
        size: Size = .reader,
        style: Style = .roman,
        alignment: TextAlignment = .center
    ) {
        self.arabic = arabic
        self.english = english
        self.size = size
        self.style = style
        self.alignment = alignment
    }

    public var body: some View {
        VStack(spacing: size.english * 0.5) {
            if let arabic, !arabic.isEmpty {
                ArabicAccentText(arabic, size: size.arabic)
            }
            Text(english)
                .font(englishFont)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(alignment)
                // A verse is never elided: `fixedSize` makes the block claim the
                // height it needs instead of truncating inside a tight container.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(english)
    }

    private var englishFont: Font {
        switch style {
        case .roman: .serifBody(size.english)
        case .italic: .serifItalic(size.english)
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

    public init(_ text: String, size: CGFloat) {
        self.text = text
        self.size = size
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
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
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
