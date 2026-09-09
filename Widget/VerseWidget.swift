import DesignSystem
import QuranData
import SwiftUI
import WidgetKit

/// One ayah on the Home or Lock Screen.
///
/// The verse is the day's `Content/discover.json` pick unless the reader pinned one
/// (`Prefs.widgetVerseRef`, shared through the App Group), the text comes from the same
/// bundled content the app reads, and a tap opens `scrollthequran://verse/<s>/<a>`.
struct VerseWidget: Widget {
    static let kind = "ScrollTheQuranVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: VerseWidget.kind, provider: VerseTimelineProvider()) { entry in
            VerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Ayah")
        .description("An ayah from the Quran, in clear English.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct VerseEntry: TimelineEntry {
    let date: Date
    let content: VerseWidgetContent

    static let placeholder = VerseEntry(date: Date(), content: .placeholder)
}

/// Seven days of entries, each starting at local midnight.
///
/// WidgetKit is free to render any entry whose date has passed, so a whole week is handed
/// over at once: the widget keeps rotating even if the extension is never woken again. The
/// reload policy asks for a refresh after the last one.
struct VerseTimelineProvider: TimelineProvider {
    static let entryCount = 7

    func placeholder(in _: Context) -> VerseEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(VerseTimelineProvider.entries(from: Date()).first ?? .placeholder)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let entries = VerseTimelineProvider.entries(from: Date())
        let next = entries.last.map { $0.date.addingTimeInterval(86400) } ?? Date().addingTimeInterval(86400)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    /// The first entry is "now" so the widget has something to draw immediately; the rest
    /// land on the following local midnights.
    static func entries(
        from now: Date,
        calendar: Calendar = .current,
        pinned: VerseRef? = nil
    ) -> [VerseEntry] {
        let startOfToday = calendar.startOfDay(for: now)
        return (0 ..< entryCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { return nil }
            return VerseEntry(
                date: offset == 0 ? now : day,
                content: VerseWidgetSource.content(on: day, calendar: calendar, pinned: pinned ?? VerseWidgetSource.pinnedVerse())
            )
        }
    }
}

/// Bridges the entry onto the shared family views and paints the widget's container.
struct VerseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    var body: some View {
        VerseWidgetView(content: entry.content, family: family)
            .containerBackground(Color.appBackground, for: .widget)
    }
}

#Preview("Small", as: .systemSmall) {
    VerseWidget()
} timeline: {
    VerseEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    VerseWidget()
} timeline: {
    VerseEntry.placeholder
}
