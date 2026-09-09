import Foundation
import QuranData

/// Where one surah sits in the flat 6,236-verse index: `globalIndex = startIndex + ayah - 1`.
///
/// `UserState` deliberately does not bundle the surah table — `QuranData` owns it. Callers hand
/// over the span for the surah they are working with, which also keeps every method here pure.
public struct SurahSpan: Hashable, Codable, Sendable {
    public let number: Int
    /// Zero-based global index of ayah 1 of this surah (Al-Fatiha is 0, Al-Baqarah is 7).
    public let startIndex: Int
    public let ayahCount: Int

    public init(number: Int, startIndex: Int, ayahCount: Int) {
        self.number = number
        self.startIndex = startIndex
        self.ayahCount = ayahCount
    }

    /// The global index of an ayah in this surah, or nil when the ayah is out of range.
    public func globalIndex(ofAyah ayah: Int) -> Int? {
        guard ayah >= 1, ayah <= ayahCount else { return nil }
        return startIndex + ayah - 1
    }

    /// The global index of `verse`, or nil when it belongs to another surah.
    public func globalIndex(of verse: VerseRef) -> Int? {
        guard verse.surah == number else { return nil }
        return globalIndex(ofAyah: verse.ayah)
    }

    /// Every global index in this surah.
    public var range: Range<Int> {
        startIndex ..< (startIndex + ayahCount)
    }
}

/// Which of the 6,236 ayat have been read, and the strings Home prints about it.
public struct ReadProgress: Hashable, Codable, Sendable {
    public static let totalVerses = BitSet6236.bitCount

    public private(set) var bits: BitSet6236

    public init(bits: BitSet6236 = BitSet6236()) {
        self.bits = bits
    }

    // MARK: Marking

    /// Marks a global index read. Returns true when this was new.
    @discardableResult
    public mutating func markRead(globalIndex: Int) -> Bool {
        bits.insert(globalIndex)
    }

    /// Marks `verse` read using its surah's span. Returns true when this was new.
    @discardableResult
    public mutating func markRead(_ verse: VerseRef, in span: SurahSpan) -> Bool {
        guard let index = span.globalIndex(of: verse) else { return false }
        return bits.insert(index)
    }

    /// Marks every ayah of a surah read.
    public mutating func markReadAll(in span: SurahSpan) {
        bits.insert(contentsOf: span.range)
    }

    @discardableResult
    public mutating func markUnread(globalIndex: Int) -> Bool {
        bits.remove(globalIndex)
    }

    public mutating func reset() {
        bits.removeAll()
    }

    // MARK: Reading

    public func isRead(globalIndex: Int) -> Bool {
        bits.contains(globalIndex)
    }

    public func isRead(_ verse: VerseRef, in span: SurahSpan) -> Bool {
        guard let index = span.globalIndex(of: verse) else { return false }
        return bits.contains(index)
    }

    /// How many ayat have been read, out of 6,236.
    public var readCount: Int {
        bits.count
    }

    /// 0...1.
    public var percent: Double {
        Double(readCount) / Double(Self.totalVerses)
    }

    /// The Home card's label: `"0%"`, `"<1%"`, `"12%"`, `"100%"`.
    ///
    /// A single ayah is 0.016% of the Quran, so plain rounding would print "0%" for weeks of
    /// reading. Anything above zero but below one percent shows `"<1%"`, and the label only
    /// says `"100%"` when every ayah really is read (99% is the ceiling before that).
    public var percentLabel: String {
        let count = readCount
        if count <= 0 {
            return "0%"
        }
        if count >= Self.totalVerses {
            return "100%"
        }
        let scaled = percent * 100
        if scaled < 1 {
            return "<1%"
        }
        return "\(min(99, Int(scaled.rounded())))%"
    }

    /// `"n of 6,236 verses"`, the line under the percentage on Home.
    public var versesReadLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        let read = formatter.string(from: NSNumber(value: readCount)) ?? "\(readCount)"
        let total = formatter.string(from: NSNumber(value: Self.totalVerses)) ?? "\(Self.totalVerses)"
        return "\(read) of \(total) verses"
    }

    // MARK: Surah completion

    public func readCount(in span: SurahSpan) -> Int {
        bits.count(in: span.range)
    }

    /// 0...1 for one surah.
    public func completion(in span: SurahSpan) -> Double {
        guard span.ayahCount > 0 else { return 0 }
        return Double(readCount(in: span)) / Double(span.ayahCount)
    }

    /// Every ayah of the surah has been read.
    public func isComplete(_ span: SurahSpan) -> Bool {
        span.ayahCount > 0 && readCount(in: span) == span.ayahCount
    }

    /// The surahs, of those given, that are fully read.
    public func completedSurahs(among spans: [SurahSpan]) -> [Int] {
        spans.filter(isComplete).map(\.number)
    }

    // MARK: Codable — `{ "version": 1, "bits": "<base64>" }`.

    private enum CodingKeys: String, CodingKey {
        case version, bits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bits = try container.decodeIfPresent(BitSet6236.self, forKey: .bits) ?? BitSet6236()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(1, forKey: .version)
        try container.encode(bits, forKey: .bits)
    }
}
