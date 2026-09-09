import DesignSystem
import QuranData
import SwiftUI

/// The surah pill's sheet: all 114 surahs, searchable by name, English meaning or number
/// (`SurahIndex.surah(named:)` already handles "baqarah", "The Cow" and "2"), grouped into
/// the juz they start in.
struct SurahPicker: View {
    let index: SurahIndex
    let currentSurah: Int
    let onSelect: (Int) -> Void
    let onDone: () -> Void

    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Surah") {
                OutlinePillButton("Done", height: ReaderMetrics.sheetDoneHeight, action: onDone)
                    .frame(width: ReaderMetrics.sheetDoneWidth)
                    .accessibilityIdentifier("surahPicker.done")
            } trailing: {
                Color.clear.frame(width: ReaderMetrics.sheetDoneWidth, height: 1)
            }

            searchField

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(Self.sections(for: query, in: index), id: \.juz) { section in
                        Section {
                            ForEach(section.surahs) { surah in
                                row(surah)
                            }
                        } header: {
                            sectionHeader(section.juz)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.sheetBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("surahPicker")
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            searchInput
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: Metrics.pillHeightCompact)
        .background(Color.cardBackground, in: .capsule)
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, Spacing.md)
    }

    /// `textInputAutocapitalization` is iOS-only, and the package also builds for the host.
    private var searchInput: some View {
        let field = TextField("Search surahs", text: $query)
            .font(.body(16))
            .foregroundStyle(Color.textPrimary)
            .autocorrectionDisabled()
            .accessibilityIdentifier("surahPicker.search")
        #if os(iOS)
            return field.textInputAutocapitalization(.never)
        #else
            return field
        #endif
    }

    private func sectionHeader(_ juz: Int) -> some View {
        Text("Juz \(juz)")
            .capsLabelStyle()
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sheetBackground)
    }

    private func row(_ surah: Surah) -> some View {
        Button {
            onSelect(surah.number)
        } label: {
            HStack(spacing: Spacing.md) {
                Text("\(surah.number)")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 28, alignment: .trailing)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(surah.name)
                        .font(.body(17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(surah.subtitle)
                        .font(.body(13))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.sm)
                if surah.number == currentSurah {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Surah \(surah.number), \(surah.name), \(surah.meaning)")
        .accessibilityAddTraits(surah.number == currentSurah ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("surahPicker.row.\(surah.number)")
    }

    struct JuzSection {
        let juz: Int
        let surahs: [Surah]
    }

    /// Matching surahs, grouped by the juz each one starts in. Static and pure, so the
    /// search behaviour is a unit test rather than a UI test.
    static func sections(for query: String, in index: SurahIndex) -> [JuzSection] {
        var byJuz: [Int: [Surah]] = [:]
        for surah in filter(query, in: index) {
            byJuz[surah.juz.first ?? 1, default: []].append(surah)
        }
        return byJuz.keys.sorted().map { JuzSection(juz: $0, surahs: byJuz[$0] ?? []) }
    }

    static func filter(_ query: String, in index: SurahIndex) -> [Surah] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return index.surahs }
        // The index's own matcher first, so "2", "baqarah" and "The Cow" all resolve; then a
        // plain contains pass, so a partial name still narrows the list as it is typed.
        if let exact = index.surah(named: trimmed) {
            return [exact]
        }
        let needle = trimmed.lowercased()
        return index.surahs.filter {
            $0.name.lowercased().contains(needle) || $0.meaning.lowercased().contains(needle)
        }
    }
}
