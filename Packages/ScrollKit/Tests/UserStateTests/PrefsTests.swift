import Foundation
import QuranData
import Testing
@testable import UserState

@Suite("Prefs")
struct PrefsTests {
    @Test("A brand new install defaults to the ClearQuran translation and no progress")
    func defaults() {
        let prefs = Prefs()
        #expect(prefs.translationID == "itani")
        #expect(prefs.onboardingDone == false)
        #expect(prefs.onboardingStep == 0)
        #expect(prefs.seenOneTimeOffer == false)
        #expect(prefs.accountID == nil)
        #expect(prefs.accountEmail == nil)
        #expect(prefs.charityVote == nil)
        #expect(prefs.widgetVerseRef == nil)
        #expect(prefs.lastReaderPosition == nil)
        #expect(prefs.isSignedIn == false)
    }

    @Test("An empty prefs file migrates to the defaults instead of failing")
    func decodesFromEmptyObject() throws {
        let prefs = try JSONDecoder().decode(Prefs.self, from: Data("{}".utf8))
        #expect(prefs == Prefs())
    }

    @Test("A prefs file written by an older build keeps what it has and defaults the rest")
    func migratesFromMissingKeys() throws {
        let json = Data(#"{"translationId":"saheeh","onboardingDone":true}"#.utf8)
        let prefs = try JSONDecoder().decode(Prefs.self, from: json)
        #expect(prefs.translationID == "saheeh")
        #expect(prefs.onboardingDone)
        #expect(prefs.onboardingStep == 0)
        #expect(prefs.seenOneTimeOffer == false)
        #expect(prefs.widgetVerseRef == nil)
    }

    @Test("Every preference round-trips, with verse refs as keys")
    func roundTripsThroughJSON() throws {
        var prefs = Prefs()
        prefs.translationID = "pickthall"
        prefs.onboardingDone = true
        prefs.onboardingStep = 4
        prefs.seenOneTimeOffer = true
        prefs.accountID = "001234.abcdef"
        prefs.accountEmail = "reader@example.com"
        prefs.charityVote = "islamic-relief"
        prefs.widgetVerseRef = VerseRef(surah: 2, ayah: 255)
        prefs.lastReaderPosition = ReaderPosition(
            verse: VerseRef(surah: 2, ayah: 282),
            page: 2,
            updatedAt: Fixture.date(2026, 9, 14, 9, 0, in: Fixture.utc)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(prefs)
        #expect(data.utf8Text.contains(#""widgetVerseRef":"2:255""#))
        #expect(try decoder.decode(Prefs.self, from: data) == prefs)
    }

    @Test("A reader position remembers the continuation page and refuses negative ones")
    func readerPositionKeepsThePage() throws {
        let position = ReaderPosition(verse: VerseRef(surah: 2, ayah: 282), page: -3)
        #expect(position.page == 0)

        let json = Data(#"{"verse":"94:5"}"#.utf8)
        let decoded = try JSONDecoder().decode(ReaderPosition.self, from: json)
        #expect(decoded.verse == VerseRef(surah: 94, ayah: 5))
        #expect(decoded.page == 0)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ReaderPosition.self, from: Data(#"{"verse":"nope"}"#.utf8))
        }
    }
}
