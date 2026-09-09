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
    static let refColumnWidth: CGFloat = 112
    /// The book glyph that jumps to the reader.
    static let rowGlyph: CGFloat = 17
}

/// A caps label with the little copy button the reference draws beside it.
struct StudySectionHeader: View {
    let section: StudySection
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            CapsLabel(
                icon: section.headerSymbol,
                text: section.displayTitle,
                size: DeepStudyMetrics.labelSize,
                tint: section.headerSymbolTint
            )
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: DeepStudyMetrics.copyGlyph, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Copy \(section.displayTitle.lowercased())")
            .accessibilityIdentifier("deepstudy.copy.\(StudyAnchor.id(for: section))")
            Spacer(minLength: 0)
        }
    }
}

/// One section's box. Tinted sections get their measured fill and a 24 pt corner;
/// the rest sit flat on the page. Composed here rather than with
/// `DesignSystem.TintedSectionBox` because the reference puts the copy button on the
/// same line as the caps label, which that component's fixed header does not allow.
struct StudySectionBox<Content: View>: View {
    let section: StudySection
    let onCopy: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            StudySectionHeader(section: section, onCopy: onCopy)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TintBackground(kind: section.tintedKind))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deepstudy.section.\(StudyAnchor.id(for: section))")
    }
}

private struct TintBackground: ViewModifier {
    let kind: TintedSectionKind?

    func body(content: Content) -> some View {
        if let kind {
            content
                .padding(Metrics.sectionBoxPadding)
                .background(kind.tint, in: .rect(cornerRadius: Radius.cardSmall, style: .continuous))
        } else {
            content
        }
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
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}
