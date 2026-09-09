import DesignSystem
import QuranData
import StudyContent
import SwiftUI
import UserState

/// The Discover tab: one full-height card per feed item, paged vertically.
///
/// The feed order comes from `DiscoverFeed.items(seed:)` with the day of the year as
/// the seed, so every device sees the same cards in the same order on the same day and
/// a snapshot run pinned to `SCROLL_FIXED_DATE` always replays it.
///
/// Free readers get `DiscoverGate.freeCardsPerDay` cards a day; landing on the fourth
/// raises the paywall instead of the card.
@MainActor
public struct DiscoverView: View {
    private let feed: DiscoverFeed
    private let themes: ThemeIndex
    private let today: Date
    private let initialKey: String?

    @Environment(TranslationStore.self) private var translations: TranslationStore?
    @Environment(StudyStore.self) private var studies: StudyStore?
    @Environment(UserStore.self) private var user: UserStore?
    @Environment(\.entitlements) private var entitlements
    @Environment(\.openPassage) private var openPassage
    @Environment(\.openNote) private var openNote

    @State private var gate: DiscoverGateStore
    @State private var currentKey: String?
    @State private var isPaywallPresented = false
    @State private var openStudy: Study?

    public init(
        feed: DiscoverFeed,
        themes: ThemeIndex = .empty,
        today: Date = Date(),
        initialKey: String? = nil,
        gate: DiscoverGateStore? = nil
    ) {
        self.feed = feed
        self.themes = themes
        self.today = today
        self.initialKey = initialKey
        _gate = State(initialValue: gate ?? DiscoverGateStore(now: today))
    }

    public var body: some View {
        GeometryReader { _ in
            content
        }
        .background(Color.appBackgroundFlat)
        .sheet(isPresented: $isPaywallPresented) {
            DiscoverLimitSheet(used: gate.used) { isPaywallPresented = false }
        }
        .fullCover(item: $openStudy) { study in
            DeepStudyView(study: study, themeTitle: themeTitle(forKey: study.key)) {
                openStudy = nil
            }
        }
        .task { syncEntitlement() }
        .onChange(of: entitlements?.isSubscribed ?? false) { _, _ in syncEntitlement() }
        .accessibilityIdentifier("discover")
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            StudyComingSoonCard()
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        page(for: item)
                            .containerRelativeFrame(.vertical)
                            .id(item.key)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentKey)
            .scrollIndicators(.hidden)
            .onAppear { land(on: currentKey ?? initialKey ?? items.first?.key) }
            .onChange(of: currentKey) { _, key in land(on: key) }
        }
    }

    private func page(for item: DiscoverItem) -> some View {
        let study = studies?.study(forKey: item.key)
        let presentation = PassagePresentation.make(
            forKey: item.key,
            translations: translations
        ) ?? PassagePresentation(
            passage: item.passage ?? PassageRef(surah: item.surah, start: 1, end: 1),
            reference: item.key,
            arabic: nil,
            english: "",
            translationTag: ""
        )
        return VStack(spacing: 0) {
            if let study {
                DiscoverCard(
                    presentation: presentation,
                    themeTitle: themeTitle(forKey: item.key) ?? study.theme,
                    study: study,
                    crossRefs: chips(for: study),
                    isSaved: user?.isSaved(presentation.passage) ?? false,
                    isRead: isRead(presentation.passage),
                    onDeepStudy: { openStudy = study },
                    onOpenReference: { openPassage($0) },
                    onSave: { user?.toggleSaved(presentation.passage) },
                    onNote: { openNote(item.key) },
                    onShare: {
                        Pasteboard.copy(
                            StudyCopy.card(
                                reference: presentation.reference,
                                quote: presentation.quoted,
                                attribution: presentation.attribution
                            )
                        )
                    },
                    onMarkRead: { markRead(presentation.passage) }
                )
                .frame(maxHeight: .infinity)
            } else {
                StudyComingSoonCard(reference: presentation.reference)
            }
        }
        .padding(.horizontal, DiscoverMetrics.cardInset)
        .padding(.vertical, DiscoverMetrics.pagePadding)
    }

    // MARK: - Data

    private var items: [DiscoverItem] {
        feed.items(on: today)
    }

    private func themeTitle(forKey key: String) -> String? {
        themes.theme(forKey: key)?.title
    }

    private func chips(for study: Study) -> [ReferenceChip] {
        study.relatedPassages.prefix(2).map { passage in
            ReferenceChip(
                passage: passage,
                title: PassagePresentation.make(for: passage, translations: translations).reference
            )
        }
    }

    // MARK: - Behaviour

    private func syncEntitlement() {
        gate.isSubscribed = entitlements?.isSubscribed ?? false
    }

    /// Counts the card that just became visible. The fourth free card of the day raises
    /// the paywall instead of being counted.
    private func land(on key: String?) {
        guard let key else { return }
        if currentKey != key {
            currentKey = key
        }
        isPaywallPresented = !gate.record(key, on: today)
    }

    private func markRead(_ passage: PassageRef) {
        guard let user, let translations else { return }
        for verse in passage.verses {
            if let index = translations.index.globalIndex(of: verse) {
                user.markRead(globalIndex: index)
            }
        }
    }

    /// A card counts as read once every ayah of its passage does.
    private func isRead(_ passage: PassageRef) -> Bool {
        guard let user, let translations else { return false }
        return passage.verses.allSatisfy { verse in
            guard let index = translations.index.globalIndex(of: verse) else { return false }
            return user.progress.isRead(globalIndex: index)
        }
    }
}

/// The sheet raised when a free reader runs out of cards.
///
/// `FeaturePaywall` is not on this module's dependency list, so Discover carries its own
/// minimal sheet. AppShell can present the real paywall in front of it once both are
/// wired; nothing here reaches into StoreKit.
struct DiscoverLimitSheet: View {
    let used: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.textPrimary)
            Text("That's today's free reading")
                .font(.serifDisplay(28, relativeTo: .title))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(
                """
                You have read \(used) of \(DiscoverGate.freeCardsPerDay) free cards today. \
                Subscribe to keep scrolling, or come back tomorrow.
                """
            )
            .font(.body(15))
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            PrimaryPillButton("See plans", action: onDismiss)
                .accessibilityIdentifier("discover.paywall.plans")
            OutlinePillButton("Not now", action: onDismiss)
                .accessibilityIdentifier("discover.paywall.dismiss")
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.huge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sheetBackground)
        .accessibilityIdentifier("discover.paywall")
    }
}
