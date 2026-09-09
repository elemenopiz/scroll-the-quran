import Foundation
@testable import UserState

/// Fixed calendars and instants, so every day-based assertion is reproducible on any machine.
enum Fixture {
    static func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static let utc = calendar("UTC")
    static let newYork = calendar("America/New_York")
    static let tokyo = calendar("Asia/Tokyo")
    static let losAngeles = calendar("America/Los_Angeles")

    /// A local instant in `calendar`'s timezone.
    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        in calendar: Calendar
    ) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        guard let date = calendar.date(from: parts) else {
            fatalError(
                "fixture instant \(year)-\(month)-\(day) \(hour):\(minute) does not exist in \(calendar.timeZone.identifier)"
            )
        }
        return date
    }
}

/// A scratch directory that cleans itself up.
final class TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UserStateTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var fileNames: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }

    func write(_ text: String, to name: String) {
        try? Data(text.utf8).write(to: url.appendingPathComponent(name, isDirectory: false))
    }

    func text(_ name: String) -> String? {
        try? String(contentsOf: url.appendingPathComponent(name, isDirectory: false), encoding: .utf8)
    }
}

/// Pretends the process has no App Group entitlement, which is what a host test binary is.
final class NoAppGroupFileManager: FileManager, @unchecked Sendable {
    override func containerURL(forSecurityApplicationGroupIdentifier _: String) -> URL? {
        nil
    }
}

/// Pretends the App Group container exists at a known path.
final class FakeAppGroupFileManager: FileManager, @unchecked Sendable {
    let container: URL

    init(container: URL) {
        self.container = container
        super.init()
    }

    override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
        container.appendingPathComponent(groupIdentifier, isDirectory: true)
    }
}

/// Al-Fatiha and Al-Baqarah, from `Content/quran/surahs.json`.
extension SurahSpan {
    static let alFatiha = SurahSpan(number: 1, startIndex: 0, ayahCount: 7)
    static let alBaqarah = SurahSpan(number: 2, startIndex: 7, ayahCount: 286)
}

extension Data {
    /// The UTF-8 text of a JSON payload, for assertions about how a model encodes.
    var utf8Text: String {
        String(bytes: self, encoding: .utf8) ?? ""
    }
}
