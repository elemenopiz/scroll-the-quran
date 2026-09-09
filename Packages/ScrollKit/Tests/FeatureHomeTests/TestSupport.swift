@testable import FeatureHome
import Foundation
import QuranData

/// The repository's `Content/` directory, found by walking up from this file. Host tests have no
/// app bundle, so everything that reads content goes through a locator rooted here.
enum HomeTestContent {
    static var contentDirectory: URL {
        if let override = ProcessInfo.processInfo.environment[ContentLocator.environmentKey], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("Content", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("plans.json").path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: "Content", isDirectory: true)
    }

    static var locator: ContentLocator {
        ContentLocator(roots: [contentDirectory])
    }

    static func catalog() throws -> ReadingPlanCatalog {
        try ReadingPlanCatalog.bundled(locator: locator)
    }

    static func surahIndex() throws -> SurahIndex {
        try SurahIndex(locator: locator)
    }

    /// A fixed UTC calendar, so a day boundary is the same on every machine.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso.count == 10 ? iso + " 09:00" : iso)!
    }

    /// A small hand-built catalog, for the cases the shipped content does not cover.
    static func fixtureCatalog() -> ReadingPlanCatalog {
        ReadingPlanCatalog(
            version: 1,
            sections: [
                ReadingPlanSection(title: "Only", eyebrow: "Eyebrow", blurb: "Blurb", planIDs: ["three-day", "missing"]),
                ReadingPlanSection(title: "Empty", planIDs: ["nope"]),
            ],
            plans: [
                ReadingPlan(
                    id: "three-day",
                    title: "Three days",
                    subtitle: "A short plan",
                    image: "lantern",
                    startHere: true,
                    section: "Only",
                    bestFor: "Testing",
                    lengthDays: 3,
                    dailyMinutes: 4,
                    about: "About the plan.",
                    schedule: [
                        ReadingPlanDay(day: 1, title: "One", refs: ["1:1-7"]),
                        ReadingPlanDay(day: 2, title: "Two", refs: ["2:255"]),
                        ReadingPlanDay(day: 3, title: "Three", refs: ["112:1-4", "113:1-5"]),
                    ]
                ),
            ]
        )
    }
}
