import DesignSystem
import QuranData
import SwiftUI

/// The per-ayah note. Autosaves on every keystroke — there is no Save button, which is why
/// the header says "Auto-saved" — and clearing the field deletes the note.
///
/// Measured from `notes-sheet.png`: Done pill top right, reference at y 141..154 pt, the verse
/// under it, a hairline at 238 pt, the "Your Notes / Auto-saved" row at 262..272 pt and the
/// editor from 283 pt, 361 pt wide and 205 pt tall.
struct NotesSheet: View {
    let reference: String
    let arabic: String?
    let english: String
    @State private var text: String
    private let onChange: (String) -> Void
    private let onDone: () -> Void

    @FocusState private var isEditing: Bool

    init(
        reference: String,
        arabic: String?,
        english: String,
        note: String,
        onChange: @escaping (String) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.reference = reference
        self.arabic = arabic
        self.english = english
        _text = State(initialValue: note)
        self.onChange = onChange
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            verse
            Rectangle()
                .fill(Color.divider)
                .frame(height: Stroke.hairline)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, Spacing.xxl)
            labels
            editor
            Spacer(minLength: 0)
        }
        .background(Color.sheetBackground)
        .onChange(of: text) { _, new in onChange(new) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notesSheet")
    }

    private var header: some View {
        HStack {
            Spacer()
            OutlinePillButton("Done", height: ReaderMetrics.sheetDoneHeight) {
                isEditing = false
                onDone()
            }
            .frame(width: ReaderMetrics.sheetDoneWidth)
            .accessibilityIdentifier("notesSheet.done")
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.top, Spacing.xl)
    }

    /// The verse being annotated, muted Arabic above the English (CLAUDE.md rule 5).
    private var verse: some View {
        VStack(spacing: Spacing.md) {
            Text(reference)
                .font(.body(ReaderMetrics.notesTitleSize, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .accessibilityIdentifier("notesSheet.reference")
            VerseText(arabic: arabic, english: english, size: .discover)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
    }

    private var labels: some View {
        HStack {
            Text("Your Notes")
                .font(.body(ReaderMetrics.notesLabelSize, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("Auto-saved")
                .font(.body(ReaderMetrics.notesLabelSize))
                .foregroundStyle(Color.textTertiary)
                .accessibilityIdentifier("notesSheet.autosaved")
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.top, Spacing.xxl)
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(.body(16))
            .foregroundStyle(Color.textPrimary)
            .scrollContentBackground(.hidden)
            .padding(Spacing.md)
            .frame(height: ReaderMetrics.notesEditorHeight)
            .background(
                Color.didYouKnowBackground,
                in: .rect(cornerRadius: ReaderMetrics.notesEditorRadius, style: .continuous)
            )
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, Spacing.md)
            .focused($isEditing)
            .accessibilityLabel("Your notes on \(reference)")
            .accessibilityIdentifier("notesSheet.editor")
            .onAppear { isEditing = true }
    }
}
