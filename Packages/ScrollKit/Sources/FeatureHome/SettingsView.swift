import DesignSystem
import QuranData
import SwiftUI
import UserState

/// "Settings / Manage Account": the translation picker, the account, restore purchases, the
/// commentary note, deleting everything, and the build.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // `@Observable`: reading `store` in `body` is enough to track it; no binding is needed.
    private let store: UserStore
    private let translations: TranslationStore?
    private let restorePurchases: (() async -> Void)?
    private let versionString: String

    @State private var isRestoring = false
    @State private var confirmingDelete = false
    @State private var showingCommentary = false

    public init(
        store: UserStore,
        translations: TranslationStore? = nil,
        restorePurchases: (() async -> Void)? = nil,
        versionString: String? = nil
    ) {
        self.store = store
        self.translations = translations
        self.restorePurchases = restorePurchases
        self.versionString = versionString ?? SettingsView.bundleVersion()
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Settings", showsDivider: true) {
                OutlinePillButton("Done", height: 40) { dismiss() }
                    .frame(width: 92)
                    .accessibilityIdentifier("settings.done")
            }
            List {
                translationSection
                accountSection
                aboutSection
                dataSection
            }
            .modifier(GroupedListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("settings")
        .sheet(isPresented: $showingCommentary) {
            CommentaryNoteSheet()
        }
        .confirmationDialog(
            "Delete everything on this device?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete my data", role: .destructive) {
                store.deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Your streak, reading progress, saved verses, notes and plan are stored only on this device. Deleting them cannot be undone."
            )
        }
    }

    // MARK: Sections

    private var translationSection: some View {
        Section {
            if let translations {
                ForEach(translations.translations) { info in
                    Button {
                        translations.select(info.id)
                        store.setTranslation(info.id)
                    } label: {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(info.name)
                                    .font(.body(17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(info.translator)
                                    .font(.body(14))
                                    .foregroundStyle(Color.textSecondary)
                                // Shown verbatim: these are the licence's own words.
                                Text(info.copyright)
                                    .font(.body(12))
                                    .foregroundStyle(Color.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if store.translationID == info.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.translation.\(info.id)")
                    .accessibilityAddTraits(store.translationID == info.id ? [.isSelected, .isButton] : .isButton)
                }
            } else {
                Text("Translations are unavailable in this build.")
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
            }
        } header: {
            CapsLabel(text: "Translation")
        }
    }

    private var accountSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                Image(systemName: store.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(store.isSignedIn ? "Signed in" : "Not signed in")
                        .font(.body(17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(store.accountEmail ?? "Everything is stored on this device.")
                        .font(.body(14))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.account")

            Button {
                Task {
                    isRestoring = true
                    await restorePurchases?()
                    isRestoring = false
                }
            } label: {
                HStack {
                    Text("Restore purchases")
                        .font(.body(17))
                        .foregroundStyle(Color.textPrimary)
                    Spacer(minLength: 0)
                    if isRestoring {
                        ProgressView()
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || restorePurchases == nil)
            .accessibilityIdentifier("settings.restorePurchases")
        } header: {
            CapsLabel(text: "Account")
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingCommentary = true
            } label: {
                HStack {
                    Text("About the commentary")
                        .font(.body(17))
                        .foregroundStyle(Color.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.aboutCommentary")

            HStack {
                Text("Version")
                    .font(.body(17))
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: 0)
                Text(versionString)
                    .font(.body(16))
                    .foregroundStyle(Color.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.version")
        } header: {
            CapsLabel(text: "About")
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Text("Delete my data")
                    .font(.body(17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("settings.deleteData")
        } footer: {
            Text("Nothing you read, save or write leaves this device.")
                .font(.body(13))
                .foregroundStyle(Color.textTertiary)
        }
    }

    static func bundleVersion(_ bundle: Bundle = .main) -> String {
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// What the study notes are and are not, plus the attributions the licences require.
struct CommentaryNoteSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "About the commentary", showsDivider: true) {
                OutlinePillButton("Done", height: 40) { dismiss() }
                    .frame(width: 92)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(
                        "The study notes in this app are written to explain context, language and meaning. They are not a fatwa, and they do not replace a teacher."
                    )
                    Text(
                        "Where a note names an Arabic term it shows the Arabic script with an English gloss. Nothing here is transliterated."
                    )
                    Text(
                        "The Arabic text is the Uthmani script from Tanzil (CC BY). The default English is ClearQuran by Talal Itani. Each translation's own copyright line is shown next to it in the Translation list."
                    )
                }
                .font(.body(16))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.xl)
            }
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("settings.commentaryNote")
    }
}

/// `.insetGrouped` only exists on iOS; the package also builds for macOS (host tests).
private struct GroupedListStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.listStyle(.insetGrouped)
        #else
            content.listStyle(.inset)
        #endif
    }
}
