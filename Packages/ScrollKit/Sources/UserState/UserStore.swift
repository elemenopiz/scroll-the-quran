import Foundation
import Observation
import QuranData

/// The app's single source of user state: streak, read progress, library, notes, plan and
/// preferences, each persisted to its own JSON file in the App Group container.
///
/// Every mutation goes through a method here, which updates the in-memory value and marks that
/// one concern dirty. Dirty concerns are written after a short debounce, so paging through the
/// reader marking ayat read does not write a file per swipe. `save()` flushes immediately
/// (scene going to background), and `waitForPendingSaves()` awaits a scheduled flush (tests).
@MainActor
@Observable
public final class UserStore {
    // MARK: State

    public internal(set) var streak: StreakState
    public internal(set) var progress: ReadProgress
    public internal(set) var library: Library
    public internal(set) var notes: Notes
    public internal(set) var plan: PlanProgress
    public internal(set) var prefs: Prefs

    /// The calendar every day-based decision uses. Tests inject a fixed timezone; the app uses
    /// `.autoupdatingCurrent`, so a flight to another timezone is picked up automatically.
    public var calendar: Calendar

    // MARK: Persistence

    @ObservationIgnored let fileStore: any UserStateFileStore
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored var dirty: Set<UserStateFile> = []
    @ObservationIgnored var saveTask: Task<Void, Never>?
    @ObservationIgnored private let encoder: JSONEncoder
    @ObservationIgnored private let decoder: JSONDecoder

    /// Files that failed to decode on the last `load()`. They are left on disk untouched and
    /// their concern starts from defaults, so one bad file never takes the others with it.
    public private(set) var unreadableFiles: Set<UserStateFile> = []

    public init(
        fileStore: any UserStateFileStore,
        calendar: Calendar = .autoupdatingCurrent,
        debounce: Duration = .milliseconds(400)
    ) {
        self.fileStore = fileStore
        self.calendar = calendar
        self.debounce = debounce
        streak = StreakState()
        progress = ReadProgress()
        library = Library()
        notes = Notes()
        plan = PlanProgress()
        prefs = Prefs()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// A store backed by a directory (the App Group container by default).
    public convenience init(
        directory: URL,
        calendar: Calendar = .autoupdatingCurrent,
        debounce: Duration = .milliseconds(400)
    ) throws {
        try self.init(
            fileStore: DirectoryUserStateFileStore(directory: directory),
            calendar: calendar,
            debounce: debounce
        )
    }

    /// The store the app and the widget use: the App Group container, or Application Support
    /// when the group is unavailable, or memory as a last resort so the app still runs.
    public static func shared(calendar: Calendar = .autoupdatingCurrent) -> UserStore {
        let directory = UserStateLocation.defaultDirectory()
        if let store = try? UserStore(directory: directory, calendar: calendar) {
            store.load()
            return store
        }
        let store = UserStore(fileStore: MemoryUserStateFileStore(), calendar: calendar)
        store.load()
        return store
    }

    // MARK: Loading

    /// Reads every file. Missing files leave their concern at its defaults; unreadable ones are
    /// recorded in `unreadableFiles` and skipped. Any `.tmp` leftovers from an interrupted
    /// write are swept: they are not `UserStateFile`s, so they were never read in the first place.
    public func load() {
        unreadableFiles = []
        (fileStore as? DirectoryUserStateFileStore)?.sweepTemporaryFiles()
        streak = decode(.streak) ?? StreakState()
        progress = decode(.progress) ?? ReadProgress()
        library = decode(.library) ?? Library()
        notes = decode(.notes) ?? Notes()
        plan = decode(.plan) ?? PlanProgress()
        prefs = decode(.prefs) ?? Prefs()
    }

    private func decode<T: Decodable>(_ file: UserStateFile) -> T? {
        guard let data = try? fileStore.read(file), !data.isEmpty else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            unreadableFiles.insert(file)
            return nil
        }
    }

    // MARK: Saving

    /// Marks a concern dirty and (re)arms the debounce.
    func touch(_ file: UserStateFile) {
        dirty.insert(file)
        saveTask?.cancel()
        let interval = debounce
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled, let self else { return }
            saveTask = nil
            writeDirtyFiles()
        }
    }

    /// Writes everything dirty right now and cancels any pending debounce.
    public func save() {
        saveTask?.cancel()
        saveTask = nil
        writeDirtyFiles()
    }

    /// Writes every concern, dirty or not — used after `deleteAllData()` and by tests.
    public func saveAll() {
        dirty = Set(UserStateFile.allCases)
        save()
    }

    /// Awaits the pending debounced write, if there is one.
    public func waitForPendingSaves() async {
        await saveTask?.value
    }

    /// True while a debounced write is still pending.
    public var hasPendingSaves: Bool {
        !dirty.isEmpty || saveTask != nil
    }

    private func writeDirtyFiles() {
        let files = dirty
        dirty = []
        for file in files {
            do {
                try fileStore.write(encoded(file), to: file)
            } catch {
                // Put it back: a full disk now should not silently lose the change forever.
                dirty.insert(file)
            }
        }
    }

    private func encoded(_ file: UserStateFile) throws -> Data {
        switch file {
        case .streak: try encoder.encode(streak)
        case .progress: try encoder.encode(progress)
        case .library: try encoder.encode(library)
        case .notes: try encoder.encode(notes)
        case .plan: try encoder.encode(plan)
        case .prefs: try encoder.encode(prefs)
        }
    }
}
