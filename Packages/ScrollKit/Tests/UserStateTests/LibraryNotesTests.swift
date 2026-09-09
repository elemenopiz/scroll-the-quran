import Foundation
import QuranData
import Testing
@testable import UserState

@Suite("Library")
struct LibraryTests {
    @Test("Saving a verse puts it at the top; saving again removes it")
    func toggleSaveOrdersMostRecentFirst() {
        var library = Library()
        let savedAyatAlKursi = library.toggleSaved(VerseRef(surah: 2, ayah: 255))
        let savedAshSharh = library.toggleSaved(VerseRef(surah: 94, ayah: 5))
        #expect(savedAyatAlKursi)
        #expect(savedAshSharh)
        #expect(library.savedVerses.map(\.key) == ["94:5", "2:255"])
        #expect(library.isSaved(VerseRef(surah: 2, ayah: 255)))

        let unsaved = library.toggleSaved(VerseRef(surah: 2, ayah: 255))
        #expect(unsaved == false)
        #expect(library.savedVerses.map(\.key) == ["94:5"])
        #expect(library.isSaved(VerseRef(surah: 2, ayah: 255)) == false)
    }

    @Test("Likes are a set: liking twice leaves one like, unliking removes it")
    func likesToggle() {
        var library = Library()
        let verse = VerseRef(surah: 1, ayah: 1)
        let liked = library.toggleLiked(verse)
        #expect(liked)
        #expect(library.isLiked(verse))
        let unliked = library.toggleLiked(verse)
        #expect(unliked == false)
        #expect(library.likedVerses.isEmpty)
    }

    @Test("Saved studies are passages and keep their own list")
    func savedStudiesArePassages() {
        var library = Library()
        let passage = PassageRef(surah: 94, start: 5, end: 6)
        let savedStudy = library.toggleSaved(passage)
        #expect(savedStudy)
        #expect(library.isSaved(passage))
        #expect(library.savedStudies.map(\.key) == ["94:5-6"])
        #expect(library.savedVerses.isEmpty)
    }

    @Test("The library encodes as key strings and round-trips")
    func roundTripsAsKeyStrings() throws {
        var library = Library()
        library.save(VerseRef(surah: 2, ayah: 255))
        library.toggleSaved(PassageRef(surah: 94, start: 5, end: 6))
        library.toggleLiked(VerseRef(surah: 112, ayah: 1))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(library)
        let json = data.utf8Text
        #expect(json.contains(#""savedVerses":["2:255"]"#))
        #expect(json.contains(#""savedStudies":["94:5-6"]"#))
        #expect(json.contains(#""likedVerses":["112:1"]"#))
        #expect(try JSONDecoder().decode(Library.self, from: data) == library)
    }

    @Test("A library file with missing keys or junk entries still loads")
    func decodesLeniently() throws {
        let json = Data(#"{"savedVerses":["2:255","nonsense"]}"#.utf8)
        let library = try JSONDecoder().decode(Library.self, from: json)
        #expect(library.savedVerses.map(\.key) == ["2:255"])
        #expect(library.savedStudies.isEmpty)
        #expect(library.likedVerses.isEmpty)
    }
}

@Suite("Notes")
struct NotesTests {
    @Test("Writing a note stores trimmed text with the time it was written")
    func setStoresTrimmedTextAndTime() {
        var notes = Notes()
        let now = Fixture.date(2026, 9, 14, 10, 0, in: Fixture.utc)
        let wrote = notes.set("  a note  ", for: "2:255", now: now)
        #expect(wrote)
        let note = notes.note(for: "2:255")
        #expect(note?.text == "a note")
        #expect(note?.updatedAt == now)
        #expect(notes.count == 1)
    }

    @Test("Rewriting the same text changes nothing; new text moves the timestamp")
    func rewritingIsIdempotent() {
        var notes = Notes()
        let first = Fixture.date(2026, 9, 14, 10, 0, in: Fixture.utc)
        let second = Fixture.date(2026, 9, 15, 10, 0, in: Fixture.utc)
        notes.set("first", for: "2:255", now: first)
        let rewroteTheSameText = notes.set("first", for: "2:255", now: second)
        #expect(rewroteTheSameText == false)
        #expect(notes.note(for: "2:255")?.updatedAt == first)
        let wroteNewText = notes.set("second", for: "2:255", now: second)
        #expect(wroteNewText)
        #expect(notes.note(for: "2:255")?.updatedAt == second)
    }

    @Test("Clearing the field deletes the note")
    func emptyTextDeletesTheNote() {
        var notes = Notes()
        let now = Fixture.date(2026, 9, 14, 10, 0, in: Fixture.utc)
        notes.set("something", for: VerseRef(surah: 2, ayah: 255), now: now)
        let cleared = notes.set("   \n ", for: VerseRef(surah: 2, ayah: 255), now: now)
        #expect(cleared)
        #expect(notes.isEmpty)
        #expect(notes.text(for: "2:255") == "")
    }

    @Test("Notes list newest first and round-trip through JSON")
    func recentOrderAndRoundTrip() throws {
        var notes = Notes()
        let calendar = Fixture.utc
        notes.set("older", for: "2:255", now: Fixture.date(2026, 9, 13, 9, 0, in: calendar))
        notes.set("newer", for: PassageRef(surah: 94, start: 5, end: 6), now: Fixture.date(2026, 9, 14, 9, 0, in: calendar))
        #expect(notes.recent.map(\.key) == ["94:5-6", "2:255"])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(notes)
        #expect(try decoder.decode(Notes.self, from: data) == notes)
    }

    @Test("An empty notes file decodes to no notes")
    func decodesFromEmptyObject() throws {
        let notes = try JSONDecoder().decode(Notes.self, from: Data("{}".utf8))
        #expect(notes.isEmpty)
    }
}
