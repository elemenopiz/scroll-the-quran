import Foundation
@testable import QuranData
import Testing

private func makeParser() throws -> VerseRefParser {
    try VerseRefParser(index: TestContent.index())
}

@Test("Numeric references parse with any of the separators people type")
func numericReferencesParse() throws {
    let parser = try makeParser()
    #expect(parser.passage("2:255")?.key == "2:255")
    #expect(parser.passage("2.255")?.key == "2:255")
    #expect(parser.passage(" 2:255 ")?.key == "2:255")
    #expect(parser.passage("94:5-6")?.key == "94:5-6")
    #expect(parser.passage("94:5–6")?.key == "94:5-6")
    #expect(parser.passage("2:285-286")?.key == "2:285-286")
    #expect(parser.verse("94:5-6") == VerseRef(surah: 94, ayah: 5))
}

@Test("Surah names parse, with or without the definite article or a surah number")
func namedReferencesParse() throws {
    let parser = try makeParser()
    #expect(parser.passage("Al-Baqarah 255")?.key == "2:255")
    #expect(parser.passage("al baqarah 255")?.key == "2:255")
    #expect(parser.passage("Baqarah 255")?.key == "2:255")
    #expect(parser.passage("Surah Al-Baqarah 255")?.key == "2:255")
    #expect(parser.passage("Al-Baqarah 2:255")?.key == "2:255")
    #expect(parser.passage("The Cow 255")?.key == "2:255")
    #expect(parser.passage("Ash-Sharh 5-6")?.key == "94:5-6")
    #expect(parser.passage("An-Nas 1")?.key == "114:1")
    #expect(parser.verse("Al-Baqarah 255") == VerseRef(surah: 2, ayah: 255))
}

@Test("A bare surah, by number or by name, means the whole surah")
func bareSurahMeansTheWholeSurah() throws {
    let parser = try makeParser()
    #expect(parser.passage("112")?.key == "112:1-4")
    #expect(parser.passage("Al-Ikhlas")?.key == "112:1-4")
    #expect(parser.passage("1")?.key == "1:1-7")
    #expect(parser.passage("Surah Al-Fatiha")?.key == "1:1-7")
}

@Test("Every verse key round-trips through the parser unchanged")
func keysRoundTrip() throws {
    let parser = try makeParser()
    let index = try TestContent.index()
    let samples = ["1:1", "1:7", "2:255", "2:282", "4:12", "5:3", "94:5", "112:1", "114:6"]
    for key in samples {
        let ref = try #require(VerseRef(key: key))
        #expect(parser.verse(ref.key) == ref)
        #expect(parser.passage(ref.key)?.key == key)
    }
    for passageKey in ["94:5-6", "2:285-286", "112:1-4"] {
        let passage = try #require(PassageRef(key: passageKey))
        #expect(parser.passage(passage.key)?.key == passageKey)
    }
    // The named form round-trips back to the numeric key too.
    for surah in index.surahs.prefix(20) {
        let named = "\(surah.name) \(surah.ayahCount)"
        #expect(parser.passage(named)?.key == "\(surah.number):\(surah.ayahCount)", "'\(named)' did not round-trip")
    }
}

@Test("Out-of-range and nonsense references are rejected")
func badReferencesAreRejected() throws {
    let parser = try makeParser()
    #expect(parser.passage("2:287") == nil, "Al-Baqarah has 286 ayat")
    #expect(parser.passage("115:1") == nil)
    #expect(parser.passage("0:1") == nil)
    #expect(parser.passage("2:0") == nil)
    #expect(parser.passage("2:255-254") == nil, "a range must not run backwards")
    #expect(parser.passage("Al-Baqarah 3:1") == nil, "the name and the number disagree")
    #expect(parser.passage("Nowhere 1") == nil)
    #expect(parser.passage("") == nil)
    #expect(parser.passage("   ") == nil)
    #expect(parser.passage("two fifty five") == nil)
    #expect(parser.passage("1:2:3:4") == nil)
}

@Test("Without an index the parser still reads the numeric forms and skips the named ones")
func numericOnlyParserWorksWithoutAnIndex() {
    let parser = VerseRefParser.numeric
    #expect(parser.passage("2:255")?.key == "2:255")
    #expect(parser.passage("94:5-6")?.key == "94:5-6")
    #expect(parser.verse("2:255") == VerseRef(surah: 2, ayah: 255))
    // No index means no ayah counts, so out-of-range numbers pass and names do not resolve.
    #expect(parser.passage("2:9999")?.key == "2:9999")
    #expect(parser.passage("Al-Baqarah 255") == nil)
    #expect(parser.passage("112") == nil)
    #expect(VerseRefParser.verse(key: "2:255") == VerseRef(surah: 2, ayah: 255))
    #expect(VerseRefParser.passage(key: "94:5-6")?.key == "94:5-6")
}
