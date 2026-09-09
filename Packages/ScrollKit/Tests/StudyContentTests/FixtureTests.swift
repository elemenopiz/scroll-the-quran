import Foundation
@testable import StudyContent
import Testing

private let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 {
        url.deleteLastPathComponent()
    }
    return url
}()

private func contentData(_ path: String) throws -> Data {
    try Data(contentsOf: repoRoot.appendingPathComponent("Content").appendingPathComponent(path))
}

private struct Shard: Decodable {
    struct Unit: Decodable {
        struct KeyTerm: Decodable {
            let term: String
            let root: String
            let gloss: String
            let note: String
        }

        struct CrossReference: Decodable {
            let ref: String
            let why: String
        }

        let key: String
        let theme: String
        let themeId: String
        let title: String
        let tier: Int
        let meaning: String
        let historicalContext: String
        let keyTerms: [KeyTerm]
        let lifeInProphetsTime: String
        let didYouKnow: String
        let theologicalSignificance: String
        let crossReferences: [CrossReference]
        let applyIt: String
        let exploreFurther: [String]
    }

    let surah: Int
    let units: [Unit]
}

private struct Surah: Decodable {
    let number: Int
    let ayahCount: Int
}

/// `"94:5-6"` -> (94, 5, 6); `"2:255"` -> (2, 255, 255).
private func parse(_ key: String) -> (surah: Int, start: Int, end: Int)? {
    let halves = key.split(separator: ":")
    guard halves.count == 2, let surah = Int(halves[0]) else { return nil }
    let range = halves[1].split(separator: "-").compactMap { Int($0) }
    guard let start = range.first, let end = range.last, range.count <= 2, start <= end else { return nil }
    return (surah, start, end)
}

@Test("The surah 1 and 112 fixtures cover every ayah of their surah exactly once")
func fixturesCoverTheirSurahs() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
    for (number, file) in [(1, "study/surah_001.json"), (112, "study/surah_112.json")] {
        let shard = try JSONDecoder().decode(Shard.self, from: contentData(file))
        #expect(shard.surah == number)
        var covered: [Int] = []
        for unit in shard.units {
            let parsed = try #require(parse(unit.key))
            #expect(parsed.surah == number)
            covered.append(contentsOf: parsed.start ... parsed.end)
        }
        #expect(covered == Array(1 ... surahs[number - 1].ayahCount), "surah \(number) coverage has a gap or overlap")
    }
}

@Test("Every fixture unit fills all nine Deep Study sections")
func fixtureUnitsAreComplete() throws {
    for file in ["study/surah_001.json", "study/surah_112.json"] {
        let shard = try JSONDecoder().decode(Shard.self, from: contentData(file))
        for unit in shard.units {
            #expect(!unit.title.isEmpty)
            #expect(!unit.themeId.isEmpty)
            #expect(unit.tier >= 1)
            #expect(unit.meaning.count > 200, "\(unit.key) meaning is too thin")
            #expect(!unit.historicalContext.isEmpty)
            #expect(unit.keyTerms.count >= 3, "\(unit.key) needs at least three key terms")
            #expect(unit.keyTerms.allSatisfy { !$0.term.isEmpty && !$0.root.isEmpty && !$0.gloss.isEmpty && !$0.note.isEmpty })
            #expect(!unit.lifeInProphetsTime.isEmpty)
            #expect(!unit.didYouKnow.isEmpty)
            #expect(!unit.theologicalSignificance.isEmpty)
            #expect(unit.crossReferences.count >= 2, "\(unit.key) needs at least two cross references")
            #expect(!unit.applyIt.isEmpty)
            #expect(!unit.exploreFurther.isEmpty)
        }
    }
}

@Test("Every reference in the fixtures points at an ayah that exists")
func fixtureReferencesAreInBounds() throws {
    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
    func check(_ key: String) throws {
        let parsed = try #require(parse(key), "\(key) is not a valid reference")
        #expect((1 ... 114).contains(parsed.surah), "\(key) has no such surah")
        #expect(parsed.end <= surahs[parsed.surah - 1].ayahCount, "\(key) runs past the end of its surah")
    }
    for file in ["study/surah_001.json", "study/surah_112.json"] {
        let shard = try JSONDecoder().decode(Shard.self, from: contentData(file))
        for unit in shard.units {
            try check(unit.key)
            for reference in unit.crossReferences {
                try check(reference.ref)
            }
            for reference in unit.exploreFurther {
                try check(reference)
            }
        }
    }
}

@Test("passages.json maps every fixture ayah to a unit that exists")
func passageMapIsConsistent() throws {
    struct Map: Decodable {
        let shards: [String: String]
        let units: [String: String]
    }
    let map = try JSONDecoder().decode(Map.self, from: contentData("study/passages.json"))
    #expect(map.shards.keys.sorted() == ["1", "112"])

    var known: Set<String> = []
    for file in map.shards.values {
        let shard = try JSONDecoder().decode(Shard.self, from: contentData(file))
        known.formUnion(shard.units.map(\.key))
    }
    #expect(map.units.count == 11)
    #expect(Set(map.units.values) == known)
    #expect(map.units["1:6"] == "1:5-7")
    #expect(map.units["112:3"] == "112:1-4")
}

@Test("Discover only draws on units that exist, and themes only reference real ayat")
func discoverAndThemesResolve() throws {
    struct Feed: Decodable {
        struct Item: Decodable {
            let key: String
            let themeId: String
        }

        let items: [Item]
    }
    struct Themes: Decodable {
        struct Theme: Decodable {
            let id: String
            let title: String
            let refs: [String]
        }

        let themes: [Theme]
    }

    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
    var known: Set<String> = []
    for file in ["study/surah_001.json", "study/surah_112.json"] {
        try known.formUnion(JSONDecoder().decode(Shard.self, from: contentData(file)).units.map(\.key))
    }

    let themes = try JSONDecoder().decode(Themes.self, from: contentData("themes.json"))
    #expect(themes.themes.count >= 10)
    #expect(Set(themes.themes.map(\.id)).count == themes.themes.count)
    for theme in themes.themes {
        #expect(!theme.refs.isEmpty)
        for ref in theme.refs {
            let parsed = try #require(parse(ref), "theme \(theme.id) has bad ref \(ref)")
            #expect(parsed.end <= surahs[parsed.surah - 1].ayahCount, "theme \(theme.id) ref \(ref) is out of bounds")
        }
    }

    let themeIDs = Set(themes.themes.map(\.id))
    let feed = try JSONDecoder().decode(Feed.self, from: contentData("discover.json"))
    #expect(!feed.items.isEmpty)
    for item in feed.items {
        #expect(known.contains(item.key), "discover item \(item.key) has no study unit")
        #expect(themeIDs.contains(item.themeId), "discover item \(item.key) has unknown theme \(item.themeId)")
    }
}

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

    let surahs = try JSONDecoder().decode([Surah].self, from: contentData("quran/surahs.json"))
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
                let parsed = try #require(parse(ref), "\(plan.id) day \(day.day) has bad ref \(ref)")
                #expect(parsed.end <= surahs[parsed.surah - 1].ayahCount, "\(plan.id) ref \(ref) is out of bounds")
            }
        }
    }

    // The juz-a-day plan must walk the whole book with no gaps and no repeats.
    let juz = try #require(plans.plans.first { $0.id == "juz-a-day" })
    var expected = 0
    for day in juz.schedule {
        for ref in day.refs {
            let parsed = try #require(parse(ref))
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
