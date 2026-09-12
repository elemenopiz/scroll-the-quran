import DesignSystem
import QuranData
import StudyContent
import SwiftUI

/// Deep Study geometry that is not already in `Metrics`.
///
/// Numbers were read off `Reference/deepstudy-*.png` (1179x2556 px for 393x852 pt, so
/// pt = px / 3) with column and row scans, the same way `DesignSystem`'s
/// `Components/README.md` was built.
enum DeepStudyMetrics {
    /// Sections and boxes both start 72 px in from the screen edge.
    static let inset = Metrics.sectionBoxInset
    /// Body copy in every prose section (line pitch 73 px = 24.3 pt at 1.371 em).
    static let bodySize: CGFloat = 17
    /// Caps labels: 33 px cap height on "BIBLICAL MEANING".
    static let labelSize: CGFloat = 11
    /// The copy glyph beside a caps label.
    static let copyGlyph: CGFloat = 13
    /// Gap between two sections (deepstudy-top: meaning body 1247 → historical box 1319).
    static let sectionGap: CGFloat = 24
    /// Cross-reference and explore rows: 122 px tall, 19 px apart.
    static let rowRadius = Radius.chip
    static let rowGap: CGFloat = 6
    /// The bold reference column inside a cross-reference row (x 111 → 470 px).
    /// Widened from the measured 112 pt because a surah name plus its numbers
    /// ("Al-An'am 6:153") is longer than the reference's "1 Peter 1:6-7".
    static let refColumnWidth: CGFloat = 124
    /// The book glyph that jumps to the reader.
    static let rowGlyph: CGFloat = 17
    /// The pinned circular buttons float over the content, so the scroll content is
    /// inset by their band: a section scrolled to by `--screenshot deepstudy#<id>`
    /// lands under them otherwise. deepstudy-mid puts ORIGINAL LANGUAGE at 107 pt,
    /// 48 pt below the top of the content area.
    static let scrollTopInset: CGFloat = 46
    /// Chip top at 121 pt on deepstudy-top, less the safe area and `scrollTopInset`.
    static let headerTopPadding: CGFloat = 16
}

/// The little copy button the reference draws beside a section's caps label.
/// It rides `TintedSectionBox`'s header slot.
struct StudyCopyButton: View {
    let section: StudySection
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: DeepStudyMetrics.copyGlyph, weight: .regular))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 28, height: 28)
                // 28 pt glyph box, 44 pt hit target (audit A11Y-5).
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Copy \(section.displayTitle.lowercased())")
        .accessibilityIdentifier("deepstudy.copy.\(StudyAnchor.id(for: section))")
    }
}

/// One section's box: `DesignSystem.TintedSectionBox` with the copy button in its
/// header slot. Tinted sections get their measured fill and a 24 pt corner (`kind`),
/// the rest sit flat on the page (`kind: nil`).
struct StudySectionBox<Content: View>: View {
    let section: StudySection
    let onCopy: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        TintedSectionBox(
            kind: section.tintedKind,
            title: section.displayTitle,
            icon: section.headerSymbol,
            iconTint: section.headerSymbolTint,
            labelSize: DeepStudyMetrics.labelSize,
            identifier: "deepstudy.section.\(StudyAnchor.id(for: section))",
            accessory: { StudyCopyButton(section: section, onCopy: onCopy) },
            content: { content }
        )
    }
}

/// Body copy for a prose section.
struct StudyProse: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.serifBody(DeepStudyMetrics.bodySize))
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// KEY ARABIC TERMS: the Arabic script in the muted layer, then the English gloss,
/// then the note. Never transliterated (CLAUDE.md rule 5).
struct KeyTermsList: View {
    let terms: [Study.KeyTerm]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(terms) { term in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                        ArabicAccentText(term.arabic, size: 20)
                            .fixedSize()
                        Text(term.gloss)
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer(minLength: 0)
                    }
                    if !term.note.isEmpty {
                        Text(term.note)
                            .font(.serifBody(15))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(term.gloss). \(term.note)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One RELATED VERSES row: bold citation, the live translation text beside it, and a
/// book glyph that opens the reader.
struct CrossReferenceRow: View {
    let title: String
    let text: String
    let identifier: String
    let open: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(title)
                .font(.body(15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: DeepStudyMetrics.refColumnWidth, alignment: .leading)
            Text(text)
                .font(.serifBody(15))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "book")
                .font(.system(size: DeepStudyMetrics.rowGlyph, weight: .regular))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rowBackground, in: .rect(cornerRadius: DeepStudyMetrics.rowRadius, style: .continuous))
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// One EXPLORE FURTHER row: the citation and the book glyph, nothing else.
struct ExploreRow: View {
    let title: String
    let identifier: String
    let open: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.body(16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Spacer(minLength: Spacing.md)
            Image(systemName: "book")
                .font(.system(size: DeepStudyMetrics.rowGlyph, weight: .regular))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rowBackground, in: .rect(cornerRadius: DeepStudyMetrics.rowRadius, style: .continuous))
        // Rows are 41 pt by measurement; the hit target reaches 44 (audit A11Y-5).
        .contentShape(Rectangle().inset(by: -1.5))
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}
