import SwiftUI

/// Every component in one scrollable, sectioned screen, for visual review and for the
/// `--screenshot gallery` snapshot route.
///
/// `ScreenID` lives in `AppShell`, which this task does not own, so the route has to be
/// registered there: add `case gallery` to `ScreenID` and render `ComponentGallery()`
/// for it in `RootView`. Until that lands the gallery is still reachable from previews.
public struct ComponentGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            ComponentGallerySections()
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("screen.gallery")
        .task { DesignSystem.registerFonts() }
    }
}

/// The gallery without its scroll view, so a host can drop it into its own container
/// and so `ImageRenderer` can capture the whole page in one pass (a `ScrollView` only
/// renders what a real scroll container would show).
public struct ComponentGallerySections: View {
    @State private var wheelSelection = [7, 6, 1]
    @State private var isSaved = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxl) {
            section("Verse") {
                VerseText(
                    arabic: VersePreviewFixture.shortArabic,
                    english: VersePreviewFixture.shortEnglish,
                    size: .reader
                )
                VerseText(
                    arabic: VersePreviewFixture.ayatAlKursiArabic,
                    english: VersePreviewFixture.ayatAlKursiEnglish,
                    size: .deepStudy,
                    style: .italic
                )
                VerseText(
                    arabic: VersePreviewFixture.shortArabic,
                    english: VersePreviewFixture.shortEnglish,
                    size: .widget
                )
            }

            section("Pills") {
                OutlinePillButton("I already signed up on the web") {}
                    .accessibilityIdentifier("gallery.outlinePill")
                PrimaryPillButton("Continue") {}
                    .accessibilityIdentifier("gallery.primaryPill")
                PrimaryPillButton("Redeem 7 days for $0.00", height: Metrics.pillHeightLarge) {}
            }

            section("Chips and labels") {
                HStack(spacing: Spacing.md) {
                    Chip("Trust in Hardship")
                    OfflineBadge()
                }
                HStack(spacing: Spacing.md) {
                    Chip("Al-Baqarah 2:286", kind: .crossReference) {}
                    Chip("Ash-Sharh 94:5-6", kind: .crossReference) {}
                }
                CapsLabel(icon: "lightbulb.fill", text: "Did you know?", tint: .ratingStar)
                CapsuleIconGroup(
                    identifierPrefix: "gallery.toolbar",
                    items: [
                        CapsuleIconItem(id: "shuffle", systemImage: "dice", label: "Random ayah") {},
                        CapsuleIconItem(id: "favourite", systemImage: "heart", label: "Favourites") {},
                    ]
                )
            }

            section("Cards") {
                StatCard(
                    systemImage: "flame.fill",
                    value: "1",
                    caption: "Days opened",
                    trailing: "square.and.arrow.up"
                ) {
                    Text("Great start. Come back tomorrow to keep it going.")
                        .font(.body(16))
                        .foregroundStyle(Color.textPrimary)
                }
                StatCard(
                    emblem: .tinted(Color(rgb: 0x8A7561)),
                    systemImage: "book.fill",
                    value: "<1%",
                    caption: "Quran read"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        ProgressBar(value: 0.008)
                        Text("1 of 114 surahs")
                            .font(.body(16))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                RowLink(systemImage: "bookmark.fill", title: "Saved", subtitle: "Your library") {}
                    .accessibilityIdentifier("gallery.rowLink")
                ReviewCard(
                    title: "Game Changer",
                    quote: "I cannot praise this app enough. It turned scrolling into "
                        + "something that grounds me instead of draining me.",
                    author: "MellowViolence"
                )
            }

            section("Deep Study sections") {
                ForEach(TintedSectionKind.allCases, id: \.self) { kind in
                    TintedSectionBox(kind: kind, title: kind == .quote ? "Ayah" : nil) {
                        Text("Measured tint for \(kind.rawValue), set in Source Serif at 17 pt.")
                            .font(.serifBody())
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }

            section("Paywall and plans") {
                VStack(spacing: 0) {
                    TimelineStep(
                        systemImage: "lock",
                        title: "Today",
                        message: "Open the Quran like never before. Full access, everything unlocked"
                    )
                    TimelineStep(
                        systemImage: "checkmark",
                        title: "Day 7",
                        message: "Pick a reading plan and continue ayah by ayah",
                        isLast: true
                    )
                }
                HStack(alignment: .top, spacing: Spacing.md) {
                    PlanCard(
                        title: "Start With Al-Fatiha",
                        meta: "7 days · about 5 min/day",
                        tagline: "The #1 place to start",
                        ribbon: "Start here"
                    ) {
                        LinearGradient.flame
                    }
                    PlanCard(title: "A Surah a Day", meta: "30 days · about 4 min/day") {
                        LinearGradient(
                            colors: [Color(rgb: 0x2F5D62), Color(rgb: 0x8A7561)],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    }
                }
            }

            section("Feedback and input") {
                StarRow(rating: 4.5)
                ActionIconRow.standard(
                    identifierPrefix: "gallery.actions",
                    isSaved: isSaved,
                    save: { isSaved.toggle() },
                    comment: {},
                    share: {},
                    markRead: {}
                )
                ToastHint(
                    systemImage: "arrow.up.left",
                    title: "Tap or slide",
                    message: "to jump to any ayah",
                    onDismiss: {}
                )
                WheelPicker3(
                    identifierPrefix: "gallery.wheel",
                    columns: [
                        .init(id: "hour", title: "Hour", options: (1 ... 12).map(String.init)),
                        .init(id: "minute", title: "Minute", options: stride(from: 0, to: 60, by: 5)
                            .map { String(format: "%02d", $0) }),
                        .init(id: "period", title: "Period", options: ["AM", "PM"]),
                    ],
                    selection: $wheelSelection
                )
            }

            section("Sheets and mockups") {
                SheetHeader(title: "Translation") {
                    OutlinePillButton("Done", height: 42) {}
                        .frame(width: 110)
                }
                PhoneFrame(screenWidth: 180) {
                    VStack {
                        Spacer()
                        VerseText(
                            arabic: VersePreviewFixture.shortArabic,
                            english: VersePreviewFixture.shortEnglish,
                            size: .widget
                        )
                        Spacer()
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, Spacing.xxl)
    }

    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            CapsLabel(text: title, size: 13)
                .accessibilityIdentifier("gallery.section.\(title.lowercased())")
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Gallery light") {
    ComponentGallery().preferredColorScheme(.light)
}

#Preview("Gallery dark") {
    ComponentGallery().preferredColorScheme(.dark)
}
