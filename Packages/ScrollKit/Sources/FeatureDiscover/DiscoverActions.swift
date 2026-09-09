import Foundation
import QuranData
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Opening the reader on a passage. `AppShell`'s `Router` is on the other side of the
/// dependency arrow (it imports this module, not the reverse), so navigation crosses
/// the seam as an environment action instead.
public struct OpenPassageAction: Sendable {
    public typealias Handler = @MainActor @Sendable (PassageRef) -> Void

    private let handler: Handler?

    public init(_ handler: Handler? = nil) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction(_ passage: PassageRef) {
        handler?(passage)
    }

    @MainActor
    public func callAsFunction(_ verse: VerseRef) {
        handler?(PassageRef(verse: verse))
    }

    /// Whether anything is listening. Views hide their chevrons when nothing is.
    public var isWired: Bool {
        handler != nil
    }
}

/// Opening the note sheet for a passage key (`"1:5-7"`). Same seam as `OpenPassageAction`.
public struct OpenNoteAction: Sendable {
    public typealias Handler = @MainActor @Sendable (String) -> Void

    private let handler: Handler?

    public init(_ handler: Handler? = nil) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction(_ key: String) {
        handler?(key)
    }

    public var isWired: Bool {
        handler != nil
    }
}

private struct OpenPassageKey: EnvironmentKey {
    static let defaultValue = OpenPassageAction()
}

private struct OpenNoteKey: EnvironmentKey {
    static let defaultValue = OpenNoteAction()
}

public extension EnvironmentValues {
    /// Injected by AppShell as `OpenPassageAction { router.open(verse:) }`.
    var openPassage: OpenPassageAction {
        get { self[OpenPassageKey.self] }
        set { self[OpenPassageKey.self] = newValue }
    }

    /// Injected by AppShell to raise the notes sheet.
    var openNote: OpenNoteAction {
        get { self[OpenNoteKey.self] }
        set { self[OpenNoteKey.self] = newValue }
    }
}

/// Puts text on the pasteboard. One place so the `#if canImport(UIKit)` lives once and
/// host tests (macOS, no UIKit) still compile.
public enum Pasteboard {
    public static func copy(_ text: String) {
        #if canImport(UIKit)
            UIPasteboard.general.string = text
        #endif
    }
}

/// `fullScreenCover` on iOS, `sheet` on the host toolchain.
///
/// The package builds for macOS too (that is how `swift test` runs the logic without a
/// simulator), and `fullScreenCover` does not exist there. Deep Study is presented
/// through this one seam so the `#if` lives in a single place.
public extension View {
    @ViewBuilder
    func fullCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
            fullScreenCover(item: item, content: content)
        #else
            sheet(item: item, content: content)
        #endif
    }
}
