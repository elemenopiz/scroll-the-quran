import DesignSystem
import QuranData
import SwiftUI

/// The card at the top of Home: pick a surah and ayah on a wheel, then open the Deep Study for
/// it. Measured against the phone-frame mockup on `onboarding-slide4-search.png`.
struct VerseSearchCard: View {
    @Bindable var model: VerseSearchModel
    var onStudy: (String) -> Void

    var body: some View {
        CardContainer(radius: Radius.card, padding: Spacing.lg) {
            VStack(spacing: 0) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: HomeMetrics.searchGlyph, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityHidden(true)
                    .padding(.bottom, Spacing.sm)

                Text("Verse Search")
                    .font(.serifDisplay(HomeMetrics.searchTitle))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Spacing.sm)

                Text("Select a verse for a deeper study")
                    .font(.body(HomeMetrics.searchSubtitle))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, Spacing.lg)

                modeTabs
                    .padding(.bottom, Spacing.xs)

                WheelPicker3(
                    identifierPrefix: "home.verseSearch",
                    columns: columns,
                    selection: $model.selection
                )
                .padding(.bottom, Spacing.sm)

                Button {
                    onStudy(model.studyKey)
                } label: {
                    Text("Study This Verse")
                        .font(.body(17, weight: .bold))
                        .foregroundStyle(Color.textOnPill)
                        .frame(maxWidth: .infinity)
                        .frame(height: HomeMetrics.studyPillHeight)
                        .background(Color.pillFill, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("home.studyThisVerse")
                .accessibilityLabel("Study this verse")
                .accessibilityValue(model.referenceLabel)
                .padding(.bottom, Spacing.lg)

                Text("Deep dive into historical context, original language, and theology.")
                    .font(.body(HomeMetrics.searchHint))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.xl)

                Label("Your saved library lives at the bottom of this page", systemImage: "arrow.down")
                    .font(.body(HomeMetrics.searchFootnote))
                    .foregroundStyle(Color.textTertiaryReadable)
                    .labelStyle(.titleAndIcon)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        // `.accessibilityElement(children: .contain)` first: an identifier on a plain container
        // is pushed down onto every descendant, which overwrote `home.studyThisVerse` and
        // `home.verseSearch.basic`/`.advanced` with `home.verseSearchCard` and left the card's
        // own frame reading as its first child's. Marking the card a container keeps the
        // identifier on the card and the children's own identifiers on the children.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.verseSearchCard")
    }

    /// The wheel's columns follow the mode: surah + ayah, plus the closing ayah in Advanced.
    private var columns: [WheelPicker3.Column] {
        let options = model.columnOptions
        var columns: [WheelPicker3.Column] = [
            .init(id: "surah", title: "Surah", options: options[0]),
            .init(id: "ayah", title: "Ayah", options: options[1]),
        ]
        if options.count > 2 {
            columns.append(.init(id: "to", title: "To ayah", options: options[2]))
        }
        return columns
    }

    private var modeTabs: some View {
        HStack(spacing: Spacing.xxxl) {
            ForEach(VerseSearchMode.allCases) { mode in
                Button {
                    model.mode = mode
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Text(mode.title)
                            .font(.body(HomeMetrics.searchTab, weight: model.mode == mode ? .semibold : .regular))
                            .foregroundStyle(model.mode == mode ? Color.textPrimary : Color.textSecondary)
                        Rectangle()
                            .fill(model.mode == mode ? Color.textPrimary : Color.clear)
                            .frame(height: HomeMetrics.tabUnderline)
                    }
                    .fixedSize()
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("home.verseSearch.\(mode.rawValue)")
                .accessibilityAddTraits(model.mode == mode ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// The Verse Search card as a screen of its own (`--screenshot verse-search`), on the same
/// background and page margin Home uses.
public struct VerseSearchView: View {
    @State private var model: VerseSearchModel
    private let navigation: (any HomeNavigation)?
    private let premium: HomePremiumStatus
    private let requestPremium: HomePremiumRequest

    public init(
        surahs: SurahIndex,
        navigation: (any HomeNavigation)? = nil,
        premium: HomePremiumStatus = .unlocked,
        requestPremium: HomePremiumRequest = HomePremiumRequest()
    ) {
        _model = State(initialValue: VerseSearchModel(index: surahs))
        self.navigation = navigation
        self.premium = premium
        self.requestPremium = requestPremium
    }

    public var body: some View {
        ScrollView {
            VerseSearchCard(model: model) { key in
                // The same gate Home applies: Verse Search's only destination is Deep Study.
                guard premium.isPremium else {
                    requestPremium(.verseSearch)
                    return
                }
                navigation?.openDeepStudy(key: key)
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, HomeMetrics.contentTopPadding)
            .padding(.bottom, HomeMetrics.contentBottomPadding)
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("verse-search")
    }
}
