import Foundation
import QuranData
@testable import StudyContent
import Testing

/// The slice of `Content/plans.json` these tests read. The full model lives in
/// `FeatureHome.ReadingPlanCatalog`; this target only checks the file itself.
private struct BundledPlans: Decodable {
    struct Section: Decodable {
        let title: String
        let planIDs: [String]
    }

    struct Plan: Decodable {
        struct Day: Decodable {
            let day: Int
            let title: String
            let refs: [String]
        }

        let id: String
        let title: String
        let section: String
        let lengthDays: Int
        let schedule: [Day]
    }

    let sections: [Section]
    let plans: [Plan]

    static func bundled() throws -> BundledPlans {
        try JSONDecoder().decode(BundledPlans.self, from: contentData("plans.json"))
    }

    func plan(_ id: String) -> Plan? {
        plans.first { $0.id == id }
    }
}

@Test("Plans schedule real ayah ranges and cover every shipped plan id")
func plansAreWellFormed() throws {
    let surahs = try bundledSurahs()
    let plans = try BundledPlans.bundled()
    #expect(plans.plans.count == 18)
    #expect(plans.sections.count == 6)
    // Plan progress is keyed by id, so these seven can never be renamed or removed.
    #expect(Set(plans.plans.map(\.id)).isSuperset(of: [
        "juz-a-day", "juz-amma", "al-kahf-fridays", "protection-verses", "patience", "gratitude", "mercy",
    ]))
    #expect(Set(plans.plans.map(\.id)) == [
        "first-week", "juz-amma", "protection-verses", "al-kahf-fridays",
        "juz-a-day", "khatm-60", "ramadan-khatm",
        "mulk-every-night", "baqarah-nights", "three-quls-morning-evening",
        "prophets-in-the-quran", "surah-yusuf",
        "patience", "gratitude", "mercy", "tawbah", "duas-of-the-quran",
        "short-surahs-40",
    ])
    #expect(plans.plan("juz-a-day")?.lengthDays == 30)
    #expect(plans.plan("juz-amma")?.lengthDays == 37)
    #expect(plans.plan("khatm-60")?.lengthDays == 60)
    #expect(plans.plan("ramadan-khatm")?.lengthDays == 30)

    let sectioned = Set(plans.sections.flatMap(\.planIDs))
    #expect(sectioned == Set(plans.plans.map(\.id)))

    for plan in plans.plans {
        #expect(plan.schedule.count == plan.lengthDays, "\(plan.id) schedule does not match its length")
        #expect(plan.schedule.map(\.day) == Array(1 ... plan.lengthDays))
        for day in plan.schedule {
            #expect(!day.refs.isEmpty)
            for ref in day.refs {
                let parsed = try #require(PassageRef(key: ref), "\(plan.id) day \(day.day) has bad ref \(ref)")
                #expect(parsed.end <= surahs[parsed.surah - 1].ayahCount, "\(plan.id) ref \(ref) is out of bounds")
            }
        }
    }
}

@Test("Every cover-to-cover plan walks the whole book with no gaps and no repeats")
func khatmPlansCoverTheWholeQuran() throws {
    let surahs = try bundledSurahs()
    let plans = try BundledPlans.bundled()
    for id in ["juz-a-day", "khatm-60", "ramadan-khatm"] {
        let plan = try #require(plans.plan(id))
        var expected = 0
        for day in plan.schedule {
            for ref in day.refs {
                let parsed = try #require(PassageRef(key: ref))
                let start = surahs.prefix(parsed.surah - 1).reduce(0) { $0 + $1.ayahCount } + parsed.start - 1
                #expect(start == expected, "\(id) skips or repeats at \(ref)")
                expected = start + (parsed.end - parsed.start + 1)
            }
        }
        #expect(expected == 6236, "\(id) stops at \(expected) of 6236 ayat")
    }
}

@Test("Juz Amma and the memorisation shelf read whole surahs, never a fragment")
func surahADayPlansReadWholeSurahs() throws {
    let surahs = try bundledSurahs()
    let plans = try BundledPlans.bundled()
    for id in ["juz-amma", "short-surahs-40"] {
        let plan = try #require(plans.plan(id))
        for day in plan.schedule {
            let ref = try #require(day.refs.first)
            #expect(day.refs.count == 1, "\(id) day \(day.day) reads more than one surah")
            let parsed = try #require(PassageRef(key: ref))
            #expect(parsed.start == 1, "\(id) day \(day.day) starts mid-surah")
            #expect(parsed.end == surahs[parsed.surah - 1].ayahCount, "\(id) day \(day.day) stops early")
        }
    }
}

@Test("Onboarding copy is complete and every unearned claim is flagged")
func onboardingCopyIsFlagged() throws {
    let json = try JSONSerialization.jsonObject(with: contentData("onboarding.json")) as? [String: Any]
    let root = try #require(json)
    let hook = try #require(root["hook"] as? [String: Any])
    #expect((hook["headline"] as? [[String: String]])?.isEmpty == false)
    #expect(hook["subheadline"] as? String == "Let's give some of that time back to Allah.")
    #expect(hook["placeholder"] as? Bool == true)

    let slides = try #require(root["slides"] as? [[String: Any]])
    #expect(slides.count == 4)
    #expect(slides.compactMap { $0["id"] as? String } == [
        "onboarding-slide1", "onboarding-slide2", "onboarding-slide3", "onboarding-slide4",
    ])

    let reviews = try #require(root["reviews"] as? [String: Any])
    #expect(reviews["placeholder"] as? Bool == true)
    let cards = try #require(reviews["cards"] as? [[String: Any]])
    #expect(cards.count == 3)
    #expect(cards.allSatisfy { $0["placeholder"] as? Bool == true })

    let legal = try #require(root["legal"] as? [String: String])
    #expect(legal["translationNotice"] == "Translation by Talal Itani, ClearQuran.com")
}

@Test("Charities are text only and the running total starts at zero")
func charitiesStartAtZero() throws {
    struct Charities: Decodable {
        struct Organisation: Decodable {
            let id: String
            let name: String
            let blurb: String
        }

        let totalGivenUSD: Int
        let organisations: [Organisation]
    }
    let charities = try JSONDecoder().decode(Charities.self, from: contentData("charities.json"))
    #expect(charities.totalGivenUSD == 0)
    #expect(charities.organisations.count == 3)
    #expect(charities.organisations.allSatisfy { !$0.name.isEmpty && !$0.blurb.isEmpty })
    #expect(Set(charities.organisations.map(\.id)).count == 3)
}
