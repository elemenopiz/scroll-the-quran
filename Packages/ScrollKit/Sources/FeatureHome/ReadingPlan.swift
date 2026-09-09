import Foundation
import QuranData

/// One day of a reading plan: `{ "day": 1, "title": "Juz 1", "refs": ["1:1-7", "2:1-141"] }`.
public struct ReadingPlanDay: Hashable, Codable, Sendable, Identifiable {
    public let day: Int
    public let title: String
    /// Passage keys, in reading order.
    public let refs: [String]

    public init(day: Int, title: String, refs: [String]) {
        self.day = day
        self.title = title
        self.refs = refs
    }

    public var id: Int {
        day
    }

    /// The refs parsed into passages, unparseable entries dropped.
    public var passages: [PassageRef] {
        refs.compactMap(PassageRef.init(key:))
    }

    /// The line Home prints under the plan title: `"Al-Baqarah 1-141"` needs a surah index,
    /// so the plain form is the raw keys joined: `"1:1-7 · 2:1-141"`.
    public var refsLine: String {
        refs.joined(separator: " · ")
    }

    /// `"Al-Fatihah 1-7 · Al-Baqarah 1-141"` when the surah table is available.
    public func refsLine(using index: SurahIndex) -> String {
        let parts = passages.map { passage -> String in
            let name = index.surah(passage.surah)?.name ?? "\(passage.surah)"
            return passage.start == passage.end
                ? "\(name) \(passage.start)"
                : "\(name) \(passage.start)-\(passage.end)"
        }
        return parts.isEmpty ? refsLine : parts.joined(separator: " · ")
    }
}

/// A reading plan from `Content/plans.json`.
public struct ReadingPlan: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    /// Cover artwork slug, e.g. `"mushaf-page"` → `PlanCover-mushaf-page` in the app catalog.
    public let image: String?
    /// The plan wears the "START HERE" ribbon in the plans grid.
    public let startHere: Bool
    public let section: String
    public let bestFor: String
    public let lengthDays: Int
    public let dailyMinutes: Int
    public let about: String
    public let schedule: [ReadingPlanDay]

    public init(
        id: String,
        title: String,
        subtitle: String,
        image: String? = nil,
        startHere: Bool = false,
        section: String,
        bestFor: String,
        lengthDays: Int,
        dailyMinutes: Int,
        about: String,
        schedule: [ReadingPlanDay]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.startHere = startHere
        self.section = section
        self.bestFor = bestFor
        self.lengthDays = lengthDays
        self.dailyMinutes = dailyMinutes
        self.about = about
        self.schedule = schedule
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            subtitle: container.decodeIfPresent(String.self, forKey: .subtitle) ?? "",
            image: container.decodeIfPresent(String.self, forKey: .image),
            startHere: container.decodeIfPresent(Bool.self, forKey: .startHere) ?? false,
            section: container.decodeIfPresent(String.self, forKey: .section) ?? "",
            bestFor: container.decodeIfPresent(String.self, forKey: .bestFor) ?? "",
            lengthDays: container.decode(Int.self, forKey: .lengthDays),
            dailyMinutes: container.decodeIfPresent(Int.self, forKey: .dailyMinutes) ?? 0,
            about: container.decodeIfPresent(String.self, forKey: .about) ?? "",
            schedule: container.decodeIfPresent([ReadingPlanDay].self, forKey: .schedule) ?? []
        )
    }

    /// `"30 days · about 45 min/day"` — the meta line on the card and the detail sheet.
    public var metaLine: String {
        let days = "\(lengthDays) day\(lengthDays == 1 ? "" : "s")"
        guard dailyMinutes > 0 else { return days }
        return "\(days) · about \(dailyMinutes) min/day"
    }

    /// `"about 45 min/day"`, for the "Daily commitment" row on the detail sheet.
    public var dailyCommitment: String {
        dailyMinutes > 0 ? "about \(dailyMinutes) min a day" : "as long as you like"
    }

    /// The schedule entry for a plan day, clamped: day 0 or past the end returns nil.
    public func day(_ number: Int) -> ReadingPlanDay? {
        schedule.first { $0.day == number }
    }
}

/// A titled group of plans in the Reading Plans sheet.
public struct ReadingPlanSection: Hashable, Codable, Sendable, Identifiable {
    public let title: String
    /// The small caps line above the section title.
    public let eyebrow: String?
    public let blurb: String?
    public let planIDs: [String]

    public init(title: String, eyebrow: String? = nil, blurb: String? = nil, planIDs: [String]) {
        self.title = title
        self.eyebrow = eyebrow
        self.blurb = blurb
        self.planIDs = planIDs
    }

    public var id: String {
        title
    }

    private enum CodingKeys: String, CodingKey {
        case title, eyebrow, blurb, planIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            title: container.decode(String.self, forKey: .title),
            eyebrow: container.decodeIfPresent(String.self, forKey: .eyebrow),
            blurb: container.decodeIfPresent(String.self, forKey: .blurb),
            planIDs: container.decodeIfPresent([String].self, forKey: .planIDs) ?? []
        )
    }
}

/// `Content/plans.json`: the sections, the plans, and lookup by id.
public struct ReadingPlanCatalog: Hashable, Codable, Sendable {
    public let version: Int
    public let sections: [ReadingPlanSection]
    public let plans: [ReadingPlan]

    private enum CodingKeys: String, CodingKey {
        case version, sections, plans
    }

    public init(version: Int = 1, sections: [ReadingPlanSection] = [], plans: [ReadingPlan] = []) {
        self.version = version
        self.sections = sections
        self.plans = plans
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            version: container.decodeIfPresent(Int.self, forKey: .version) ?? 1,
            sections: container.decodeIfPresent([ReadingPlanSection].self, forKey: .sections) ?? [],
            plans: container.decodeIfPresent([ReadingPlan].self, forKey: .plans) ?? []
        )
    }

    /// Loads `Content/plans.json` through the shared locator.
    public static func bundled(locator: ContentLocator = .shared) throws -> ReadingPlanCatalog {
        try locator.decode(ReadingPlanCatalog.self, from: "plans.json")
    }

    public var isEmpty: Bool {
        plans.isEmpty
    }

    public func plan(_ id: String) -> ReadingPlan? {
        plans.first { $0.id == id }
    }

    /// The plans of a section, in the order the section lists them; unknown ids are dropped.
    public func plans(in section: ReadingPlanSection) -> [ReadingPlan] {
        section.planIDs.compactMap(plan)
    }

    /// Sections that actually resolve to at least one plan — an empty section is not a heading
    /// with nothing under it, it is a section that should not be drawn.
    public var populatedSections: [ReadingPlanSection] {
        sections.filter { !plans(in: $0).isEmpty }
    }
}
