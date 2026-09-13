import Foundation

/// One REFLECTION card of the Discover feed: a saying, who said it, and where it can be found.
///
/// A reflection carries no verse and opens no study sheet — that is what separates it from a
/// `DiscoverItem`. `Tools/content-gen/build-reflections.mjs` writes these rows from
/// `Tools/content-gen/reflections/catalogue.mjs`, and only entries it can place in the cited
/// work at high confidence are written at all, so everything decoded here is shippable.
public struct Reflection: Codable, Hashable, Sendable, Identifiable {
    /// Where the saying can be checked. `translator` is always `"own"`: every rendering in the
    /// app is made from the Arabic or Persian for the card, never copied from a translation.
    public struct Source: Codable, Hashable, Sendable {
        public let work: String
        /// A canonical number where the number is certain ("2699"), otherwise the book or
        /// chapter of the work ("the Book of the Stories of the Prophets").
        public let locator: String
        public let translator: String

        public init(work: String, locator: String, translator: String = "own") {
            self.work = work
            self.locator = locator
            self.translator = translator
        }

        /// The provenance line, as a sheet or a share card would print it: "Sahih Muslim 2699",
        /// or "Sahih Muslim, the Book of Faith" where the locator is a chapter rather than a
        /// number — a number reads as part of the title, a phrase needs the comma.
        public var citation: String {
            guard !locator.isEmpty else { return work }
            let isNumber = locator.allSatisfy(\.isNumber)
            return isNumber ? "\(work) \(locator)" : "\(work), \(locator)"
        }
    }

    public let id: String
    /// The saying, 10-45 words, English only.
    public let text: String
    /// Exactly what the card prints under the quote — "The Prophet Muhammad (peace be upon him)",
    /// "Ali ibn Abi Talib", "Rumi". Never an honorific glyph.
    public let attribution: String
    public let source: Source
    /// An Arabic term central to the saying, in Arabic script, for the muted line. Decorative,
    /// like every other Arabic surface in the app: it never carries the accessibility label.
    public let arabic: String?
    /// Theme ids from `Content/themes.json`, so a reflection can sit beside the verses it rhymes with.
    public let themes: [String]
    public let confidence: String

    public init(
        id: String,
        text: String,
        attribution: String,
        source: Source,
        arabic: String? = nil,
        themes: [String] = [],
        confidence: String = "high"
    ) {
        self.id = id
        self.text = text
        self.attribution = attribution
        self.source = source
        self.arabic = arabic
        self.themes = themes
        self.confidence = confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        attribution = try container.decode(String.self, forKey: .attribution)
        source = try container.decode(Source.self, forKey: .source)
        arabic = try container.decodeIfPresent(String.self, forKey: .arabic)
        themes = try container.decodeIfPresent([String].self, forKey: .themes) ?? []
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "high"
    }
}

/// The on-disk wrapper, as `build-reflections.mjs` writes it:
/// `{version, generatedBy, generatedAt, count, items}`. Everything but `items` is provenance.
public struct ReflectionsFile: Codable, Hashable, Sendable {
    public let version: Int?
    public let generatedBy: String?
    public let generatedAt: String?
    public let count: Int?
    public let items: [Reflection]

    public init(
        version: Int? = nil,
        generatedBy: String? = nil,
        generatedAt: String? = nil,
        count: Int? = nil,
        items: [Reflection]
    ) {
        self.version = version
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.count = count
        self.items = items
    }
}

/// `Content/reflections.json`, ordered for the day.
///
/// Shaped like `DiscoverFeed` on purpose: the file order is only a base, `items(seed:)` shuffles
/// deterministically, and every device on the same seed sees the same order. The Discover feed
/// interleaves the two, so both have to replay identically from the same day number.
public struct ReflectionStore: Hashable, Sendable {
    /// The entries, de-duplicated by id and held in a stable base order: by id.
    public let items: [Reflection]

    private let byTheme: [String: [String]]

    public init(items: [Reflection]) {
        var seen: Set<String> = []
        let kept = items
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.id < $1.id }
        self.items = kept

        var index: [String: [String]] = [:]
        for reflection in kept {
            for theme in reflection.themes where !(index[theme]?.contains(reflection.id) ?? false) {
                index[theme, default: []].append(reflection.id)
            }
        }
        byTheme = index
    }

    public init(loader: StudyContentLoading, path: String = "reflections.json") throws {
        let file = try JSONDecoder().decode(ReflectionsFile.self, from: loader.data(at: path))
        self.init(items: file.items)
    }

    public static let empty = ReflectionStore(items: [])

    public var isEmpty: Bool {
        items.isEmpty
    }

    public var count: Int {
        items.count
    }

    public func reflection(id: String) -> Reflection? {
        items.first { $0.id == id }
    }

    /// Every reflection filed under a theme, in base order.
    public func reflections(theme: String) -> [Reflection] {
        let ids = Set(byTheme[theme] ?? [])
        return items.filter { ids.contains($0.id) }
    }

    /// The order for a seed — in practice `Calendar.dayOfYear`. Same seed, same order, always.
    ///
    /// Fisher-Yates spelled out rather than `shuffled(using:)`, for the same reason `DiscoverFeed`
    /// spells it out: the stdlib is free to change how it consumes a generator, and this order
    /// has to stay identical across the app, the widget and the tests forever.
    public func items(seed: Int) -> [Reflection] {
        var generator = SeededGenerator(seed: seed)
        var shuffled = items
        guard shuffled.count > 1 else { return shuffled }
        for index in stride(from: shuffled.count - 1, to: 0, by: -1) {
            let pick = Int(generator.next() % UInt64(index + 1))
            shuffled.swapAt(index, pick)
        }
        return shuffled
    }

    public func ids(seed: Int) -> [String] {
        items(seed: seed).map(\.id)
    }

    /// Today's order in the given calendar. Kept separate from `items(seed:)` so tests never
    /// depend on the clock.
    public func items(on date: Date, calendar: Calendar = .current) -> [Reflection] {
        items(seed: calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
    }
}
