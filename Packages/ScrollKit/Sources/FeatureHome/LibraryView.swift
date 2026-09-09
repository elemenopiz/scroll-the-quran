import DesignSystem
import QuranData
import SwiftUI
import UserState

/// "Saved / Your library": the saved verses, the saved Deep Study passages and the notes, each
/// row swipeable to delete.
///
/// Every verse row carries the muted Arabic Uthmani line above the English (CLAUDE.md rule 5):
/// centred, right to left, `Tokens.textTertiary`, hidden from VoiceOver, never transliterated.
public struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss

    // `@Observable`: reading `store` in `body` is enough to track it; no binding is needed.
    private let store: UserStore
    private let surahs: SurahIndex?
    private let translations: TranslationStore?
    private let navigation: (any HomeNavigation)?

    public init(
        store: UserStore,
        surahs: SurahIndex? = nil,
        translations: TranslationStore? = nil,
        navigation: (any HomeNavigation)? = nil
    ) {
        self.store = store
        self.surahs = surahs
        self.translations = translations
        self.navigation = navigation
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Your library", showsDivider: true) {
                OutlinePillButton("Done", height: 40) { dismiss() }
                    .frame(width: 92)
                    .accessibilityIdentifier("library.done")
            }
            if isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("library")
    }

    private var isEmpty: Bool {
        store.library.savedVerses.isEmpty && store.library.savedStudies.isEmpty && store.notes.isEmpty
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 0)
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.textTertiary)
            Text("Nothing saved yet")
                .font(.body(19, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text("Save an ayah from the reader or a study from Discover and it will be waiting here.")
                .font(.body(15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("library.empty")
    }

    private var list: some View {
        List {
            if !store.library.savedVerses.isEmpty {
                Section {
                    ForEach(store.library.savedVerses, id: \.key) { verse in
                        Button {
                            navigation?.open(verse: verse)
                        } label: {
                            verseRow(verse)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.verse.\(verse.key)")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.toggleSaved(verse)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    CapsLabel(text: "Saved verses")
                }
            }

            if !store.library.savedStudies.isEmpty {
                Section {
                    ForEach(store.library.savedStudies, id: \.key) { passage in
                        Button {
                            navigation?.openDeepStudy(key: passage.key)
                        } label: {
                            studyRow(passage)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.study.\(passage.key)")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.toggleSaved(passage)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    CapsLabel(text: "Saved studies")
                }
            }

            if !store.notes.isEmpty {
                Section {
                    ForEach(store.notes.recent) { note in
                        Button {
                            open(key: note.key)
                        } label: {
                            noteRow(note)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.note.\(note.key)")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.setNote("", for: note.key)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    CapsLabel(text: "Notes")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // MARK: Rows

    private func verseRow(_ verse: VerseRef) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(reference(for: verse))
                .capsLabelStyle()
                .foregroundStyle(Color.textSecondary)
            VerseText(
                arabic: translations?.arabic(for: verse),
                english: translations?.text(for: verse) ?? verse.key,
                size: .discover,
                alignment: .leading
            )
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private func studyRow(_ passage: PassageRef) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reference(for: passage))
                    .font(.body(17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Deep Study")
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(.rect)
    }

    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(referenceLabel(forKey: note.key))
                .capsLabelStyle()
                .foregroundStyle(Color.textSecondary)
            Text(note.text)
                .font(.body(16))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3)
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    // MARK: Helpers

    private func open(key: String) {
        if let verse = VerseRef(key: key), verse.ayah > 0, !key.contains("-") {
            navigation?.open(verse: verse)
        } else {
            navigation?.openDeepStudy(key: key)
        }
    }

    private func reference(for verse: VerseRef) -> String {
        surahs?.surah(verse.surah)?.reference(for: verse.ayah) ?? verse.key
    }

    private func reference(for passage: PassageRef) -> String {
        surahs?.surah(passage.surah)?.reference(for: passage) ?? passage.key
    }

    private func referenceLabel(forKey key: String) -> String {
        guard let passage = PassageRef(key: key) else { return key }
        return reference(for: passage)
    }
}
