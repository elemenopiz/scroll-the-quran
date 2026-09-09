import DesignSystem
import QuranData
import SwiftUI
import WidgetKit

/// One ayah on the Lock or Home Screen. Phase 1 pins it to Al-Fatiha 1:1;
/// Phase 3 reads `widgetVerseRef` out of the App Group and rotates daily.
struct VerseWidget: Widget {
    static let kind = "ScrollTheQuranVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: VerseWidget.kind, provider: VerseTimelineProvider()) { entry in
            VerseWidgetView(entry: entry)
                .containerBackground(Color.appBackground, for: .widget)
        }
        .configurationDisplayName("Daily Ayah")
        .description("An ayah from the Quran, in clear English.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct VerseEntry: TimelineEntry {
    let date: Date
    let reference: String
    let text: String

    static let placeholder = VerseEntry(
        date: Date(),
        reference: "Al-Fatiha 1:1",
        text: "In the name of God, the Gracious, the Merciful"
    )
}

struct VerseTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> VerseEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(BundledVerses.entry(for: VerseRef(surah: 1, ayah: 1)))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let entry = BundledVerses.entry(for: VerseRef(surah: 1, ayah: 1))
        let nextMidnight = Calendar.current.nextDate(
            after: entry.date,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? entry.date.addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

/// Reads the same bundled `Content/` the app ships. No network, ever.
enum BundledVerses {
    private struct Surah: Decodable {
        let number: Int
        let name: String
        let ayahCount: Int
        let startIndex: Int
    }

    private static func load<T: Decodable>(_ type: T.Type, _ name: String, in subdirectory: String) -> T? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "json",
            subdirectory: subdirectory
        ), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func entry(for verse: VerseRef, date: Date = Date()) -> VerseEntry {
        guard let surahs = load([Surah].self, "surahs", in: "Content/quran"),
              let surah = surahs.first(where: { $0.number == verse.surah }),
              verse.ayah <= surah.ayahCount,
              let verses = load([String].self, "itani", in: "Content/quran")
        else { return VerseEntry(date: date, reference: VerseEntry.placeholder.reference, text: VerseEntry.placeholder.text) }

        let index = surah.startIndex + verse.ayah - 1
        guard verses.indices.contains(index) else {
            return VerseEntry(date: date, reference: VerseEntry.placeholder.reference, text: VerseEntry.placeholder.text)
        }
        return VerseEntry(
            date: date,
            reference: "\(surah.name) \(verse.surah):\(verse.ayah)",
            text: verses[index]
        )
    }
}

struct VerseWidgetView: View {
    let entry: VerseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(entry.reference)
                .capsLabelStyle()
                .foregroundStyle(Color.textSecondary)
            Text(entry.text)
                .font(.serifBody(15))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(5)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "scrollthequran://verse/1/1"))
    }
}

#Preview("Verse widget", as: .systemSmall) {
    VerseWidget()
} timeline: {
    VerseEntry.placeholder
}
