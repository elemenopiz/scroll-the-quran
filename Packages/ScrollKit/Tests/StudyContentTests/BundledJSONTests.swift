import Foundation
import QuranData
@testable import StudyContent
import Testing

@Test("Plans schedule real ayah ranges and cover the seven Phase 1 plans")
func plansAreWellFormed() throws {
    struct Plans: Decodable {
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
    }

    let surahs = try bundledSurahs()
    let plans = try JSONDecoder().decode(Plans.self, from: contentData("plans.json"))
    #expect(plans.plans.count >= 6)
    #expect(Set(plans.plans.map(\.id)).isSuperset(of: [
        "juz-a-day", "juz-amma", "al-kahf-fridays", "protection-verses", "patience", "gratitude", "mercy",
    ]))
    #expect(plans.plans.first { $0.id == "juz-a-day" }?.lengthDays == 30)
    #expect(plans.plans.first { $0.id == "juz-amma" }?.lengthDays == 37)

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

    // The juz-a-day plan must walk the whole book with no gaps and no repeats.
    let juz = try #require(plans.plans.first { $0.id == "juz-a-day" })
    var expected = 0
    for day in juz.schedule {
        for ref in day.refs {
            let parsed = try #require(PassageRef(key: ref))
            let start = surahs.prefix(parsed.surah - 1).reduce(0) { $0 + $1.ayahCount } + parsed.start - 1
            #expect(start == expected, "juz-a-day skips or repeats at \(ref)")
            expected = start + (parsed.end - parsed.start + 1)
        }
    }
    #expect(expected == 6236)
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
