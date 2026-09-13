import DesignSystem
import QuranData
import StudyContent
import SwiftUI

/// "Related Verses": the unit's cross references, each with the one line that says why it is
/// related and the opening of the ayah itself. Tapping one opens it in the reader.
struct RelatedVersesSheet: View {
    let reference: String
    let references: [Study.CrossRef]
    /// The English of a passage in the selected translation.
    let text: (PassageRef) -> String
    let onOpen: (VerseRef) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if rows.isEmpty {
                    Text("This passage has no cross references yet.")
                        .font(.body(VerseMenuMetrics.rowSubtitleSize))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("reader.relatedVerses.empty")
                } else {
                    ForEach(rows, id: \.passage.key) { row in
                        button(row)
                    }
                }
            }
            .padding(.horizontal, VerseMenuMetrics.versePadding)
            .padding(.vertical, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(Color.cardBackground)
        .navigationTitle(reference)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader.relatedVerses")
    }

    /// One rendered row: the cross reference that parses, plus its text.
    private struct Row {
        let passage: PassageRef
        let why: String
    }

    /// A `ref` that does not parse is dropped rather than drawn as a dead row.
    private var rows: [Row] {
        references.compactMap { crossRef in
            crossRef.passage.map { Row(passage: $0, why: crossRef.why) }
        }
    }

    private func button(_ row: Row) -> some View {
        Button {
            onOpen(VerseRef(surah: row.passage.surah, ayah: row.passage.start))
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(row.passage.key)
                    .font(.body(VerseMenuMetrics.rowSubtitleSize, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                if !row.why.isEmpty {
                    Text(row.why)
                        .font(.body(VerseMenuMetrics.relatedWhySize))
                        .foregroundStyle(Color.textTertiaryReadable)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(text(row.passage))
                    .font(.serifBody(VerseMenuMetrics.rowSubtitleSize))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                Color.rowBackground,
                in: .rect(cornerRadius: Radius.chip, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(row.passage.key). \(row.why)")
        .accessibilityIdentifier("reader.relatedVerses.\(row.passage.key)")
    }
}
