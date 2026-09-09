@testable import QuranData
import Testing

@Test("Verse keys round-trip through parsing")
func verseKeyRoundTrips() {
    let ref = VerseRef(key: "2:255")
    #expect(ref == VerseRef(surah: 2, ayah: 255))
    #expect(ref?.key == "2:255")
    #expect(VerseRef(key: "2:255:1") == nil)
    #expect(VerseRef(key: "0:1") == nil)
    #expect(VerseRef(key: "two:255") == nil)
}

@Test("Passage keys collapse single-ayah ranges")
func passageKeyCollapsesSingletons() {
    let span = PassageRef(key: "94:5-6")
    #expect(span?.key == "94:5-6")
    #expect(span?.verses.map(\.key) == ["94:5", "94:6"])
    #expect(PassageRef(key: "2:255")?.key == "2:255")
    #expect(PassageRef(key: "2:255-254") == nil)
}
