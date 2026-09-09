import Foundation
import Observation
import QuranData

/// Which shape the Verse Search wheel is in.
public enum VerseSearchMode: String, CaseIterable, Sendable, Identifiable {
    /// Surah and ayah — one verse.
    case basic
    /// Surah, first ayah and last ayah — a passage.
    case advanced

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .basic: "Basic"
        case .advanced: "Advanced"
        }
    }
}

/// The state behind the Verse Search card: which surah, which ayah, and — in Advanced — which
/// last ayah. All of the clamping lives here so the wheel can never produce a reference that is
/// not in the Quran (`2:300`, or a range that runs backwards).
@MainActor
@Observable
public final class VerseSearchModel {
    public let index: SurahIndex

    public var mode: VerseSearchMode {
        didSet { clamp() }
    }

    /// 1-based surah number.
    public private(set) var surah: Int
    /// 1-based first ayah.
    public private(set) var ayah: Int
    /// 1-based last ayah; only meaningful in `.advanced`, always `>= ayah`.
    public private(set) var toAyah: Int

    public init(
        index: SurahIndex,
        mode: VerseSearchMode = .advanced,
        surah: Int = 1,
        ayah: Int = 1,
        toAyah: Int? = nil
    ) {
        self.index = index
        self.mode = mode
        self.surah = surah
        self.ayah = ayah
        self.toAyah = toAyah ?? ayah
        clamp()
    }

    // MARK: Options

    public var surahNames: [String] {
        index.surahs.map(\.name)
    }

    public var ayahCount: Int {
        index.surah(surah)?.ayahCount ?? 1
    }

    /// `["1", "2", … "n"]` for the selected surah.
    public var ayahNumbers: [String] {
        guard ayahCount >= 1 else { return ["1"] }
        return (1 ... ayahCount).map(String.init)
    }

    /// The last-ayah column starts at the first ayah, so the range can never invert.
    public var toAyahNumbers: [String] {
        guard ayah <= ayahCount else { return ["\(ayah)"] }
        return (ayah ... ayahCount).map(String.init)
    }

    /// The wheel columns, in on-screen order. Two in Basic, three in Advanced.
    public var columnOptions: [[String]] {
        switch mode {
        case .basic: [surahNames, ayahNumbers]
        case .advanced: [surahNames, ayahNumbers, toAyahNumbers]
        }
    }

    // MARK: Selection, as wheel indices

    /// `WheelPicker3` speaks in zero-based option indices; this is the bridge both ways.
    public var selection: [Int] {
        get {
            switch mode {
            case .basic: [surah - 1, ayah - 1]
            case .advanced: [surah - 1, ayah - 1, max(0, toAyah - ayah)]
            }
        }
        set { apply(selection: newValue) }
    }

    func apply(selection: [Int]) {
        guard !selection.isEmpty else { return }
        let previousSurah = surah
        surah = min(max(selection[0] + 1, 1), max(index.count, 1))
        if surah != previousSurah {
            // The ayah column's contents just changed under the wheel: An-Nas has no ayah 255
            // to hold on to, so the selection starts again at the top of the new surah.
            ayah = 1
            toAyah = 1
        } else {
            if selection.count > 1 {
                ayah = selection[1] + 1
            }
            if mode == .advanced, selection.count > 2 {
                toAyah = ayah + selection[2]
            }
        }
        clamp()
    }

    /// Fits every field to the selected surah and keeps the range the right way round.
    func clamp() {
        let count = max(index.count, 1)
        surah = min(max(surah, 1), count)
        let ayat = max(ayahCount, 1)
        ayah = min(max(ayah, 1), ayat)
        switch mode {
        case .basic:
            toAyah = ayah
        case .advanced:
            toAyah = min(max(toAyah, ayah), ayat)
        }
    }

    // MARK: Result

    public var verse: VerseRef {
        VerseRef(surah: surah, ayah: ayah)
    }

    /// The passage the "Study This Verse" button opens: one ayah in Basic, a range in Advanced.
    public var passage: PassageRef {
        PassageRef(surah: surah, start: ayah, end: mode == .advanced ? toAyah : ayah)
    }

    /// `"2:255"` or `"2:255-257"` — the key Deep Study is addressed by.
    public var studyKey: String {
        passage.key
    }

    /// `"Al-Baqarah 2:255"`, for VoiceOver and the button's accessibility value.
    public var referenceLabel: String {
        let name = index.surah(surah)?.name ?? "\(surah)"
        return mode == .advanced && toAyah > ayah
            ? "\(name) \(surah):\(ayah)-\(toAyah)"
            : "\(name) \(surah):\(ayah)"
    }
}
