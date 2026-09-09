import Foundation

/// A fixed 6,236-bit set — one bit per ayah in the Quran — stored as 98 64-bit words and
/// encoded as a single base64 string (784 bytes, ~1 KB of JSON) so read progress stays a
/// constant, tiny file no matter how much of the book has been read.
public struct BitSet6236: Hashable, Codable, Sendable {
    /// Every ayah in the Quran.
    public static let bitCount = 6236
    /// 98 words: `ceil(6236 / 64)`.
    public static let wordCount = (bitCount + 63) / 64

    private var words: [UInt64]

    public init() {
        words = Array(repeating: 0, count: Self.wordCount)
    }

    /// Valid bit positions, `0 ..< 6236`.
    public static var indices: Range<Int> {
        0 ..< bitCount
    }

    public static func isValid(_ index: Int) -> Bool {
        indices.contains(index)
    }

    public func contains(_ index: Int) -> Bool {
        guard Self.isValid(index) else { return false }
        return words[index / 64] & (1 << UInt64(index % 64)) != 0
    }

    /// Sets a bit. Returns true when it was not already set; out-of-range indices are ignored.
    @discardableResult
    public mutating func insert(_ index: Int) -> Bool {
        guard Self.isValid(index), !contains(index) else { return false }
        words[index / 64] |= (1 << UInt64(index % 64))
        return true
    }

    /// Clears a bit. Returns true when it had been set.
    @discardableResult
    public mutating func remove(_ index: Int) -> Bool {
        guard Self.isValid(index), contains(index) else { return false }
        words[index / 64] &= ~(1 << UInt64(index % 64))
        return true
    }

    public mutating func insert(contentsOf indices: some Sequence<Int>) {
        for index in indices {
            insert(index)
        }
    }

    public mutating func removeAll() {
        words = Array(repeating: 0, count: Self.wordCount)
    }

    /// How many bits are set.
    public var count: Int {
        words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    public var isEmpty: Bool {
        count == 0
    }

    /// How many bits are set inside `range` (clamped to the Quran's bounds).
    public func count(in range: Range<Int>) -> Int {
        let clamped = range.clamped(to: Self.indices)
        var total = 0
        for index in clamped where contains(index) {
            total += 1
        }
        return total
    }

    /// The set bits, ascending. Used by tests and by "resume where you left off" maths.
    public var setIndices: [Int] {
        Self.indices.filter(contains)
    }

    // MARK: Codable — little-endian bytes, base64.

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64 = try container.decode(String.self)
        guard let data = Data(base64Encoded: base64) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Read progress is not base64")
        }
        self.init(data: data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }

    /// Little-endian byte view of the words. Short or long input is padded/truncated so a
    /// file written by an older or newer build never crashes the app.
    public init(data: Data) {
        var words = Array(repeating: UInt64(0), count: Self.wordCount)
        let bytes = [UInt8](data)
        for (offset, byte) in bytes.enumerated() {
            let word = offset / 8
            guard word < words.count else { break }
            words[word] |= UInt64(byte) << UInt64((offset % 8) * 8)
        }
        // Anything above bit 6,235 in the last word is not a verse.
        let spare = Self.wordCount * 64 - Self.bitCount
        if spare > 0, let last = words.last {
            words[words.count - 1] = last & (UInt64.max >> UInt64(spare))
        }
        self.words = words
    }

    public var data: Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(Self.wordCount * 8)
        for word in words {
            for byte in 0 ..< 8 {
                bytes.append(UInt8(truncatingIfNeeded: word >> UInt64(byte * 8)))
            }
        }
        return Data(bytes)
    }
}
