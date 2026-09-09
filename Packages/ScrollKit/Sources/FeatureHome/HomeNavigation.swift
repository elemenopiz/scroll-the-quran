import Foundation
import QuranData

/// The seam between Home and the rest of the app.
///
/// Home never knows what a reader or a Deep Study page is; it hands a reference to whoever is
/// listening. `AppShell` implements this on top of its `Router` in Phase 3e. Everything is
/// optional at the call site — a `nil` navigation makes the buttons inert, which is exactly what
/// a preview and a snapshot run want.
@MainActor
public protocol HomeNavigation: AnyObject {
    /// Open one ayah in the reader (a saved verse, a search result in Basic mode).
    func open(verse: VerseRef)
    /// Open the Deep Study page for a verse or passage key (`"2:255"`, `"94:5-6"`).
    func openDeepStudy(key: String)
    /// Open the reader on a plan day's passages, in reading order.
    func openReader(refs: [String])
}

/// Records what Home asked for. Used by previews, snapshots and tests.
@MainActor
public final class RecordingHomeNavigation: HomeNavigation {
    public private(set) var openedVerses: [VerseRef] = []
    public private(set) var openedStudyKeys: [String] = []
    public private(set) var openedReaderRefs: [[String]] = []

    public init() {}

    public func open(verse: VerseRef) {
        openedVerses.append(verse)
    }

    public func openDeepStudy(key: String) {
        openedStudyKeys.append(key)
    }

    public func openReader(refs: [String]) {
        openedReaderRefs.append(refs)
    }
}
