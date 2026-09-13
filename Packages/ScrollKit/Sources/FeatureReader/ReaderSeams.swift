import Foundation
import SwiftUI

// The three things the verse menu needs from outside `FeatureReader`.
//
// `FeatureReader` sits below `AppShell` and beside `FeatureDiscover` in the dependency
// graph (`Package.swift` is frozen), so it can name neither `Router` nor Deep Study nor
// `Commerce`. Exactly like `FeatureDiscover`'s `OpenPassageAction` / `RequestPremiumAction`
// and `FeatureHome`'s `HomePremiumRequest`, the shell hands these down the environment and
// this module never learns what is on the other side.
//
// Nothing listening is a *valid* state — previews, package previews and the host tests all
// run that way — so every seam reports `isWired` and the menu degrades rather than misleads:
// an unwired premium request leaves the reader on the menu instead of showing a paywall that
// does not exist.

// MARK: - Entitlement

/// Whether the reader has paid, as a value rather than an object.
///
/// A value, not a protocol, because the shell reads `entitlements.isPremium` inside `TabRoot`'s
/// own `body` — which is what makes the observation dependency — and hands the answer down. One
/// less adapter than `FeatureDiscover`'s `EntitlementProviding`, and the free tier is the
/// default so an un-injected environment locks rather than unlocks.
public struct ReaderPremium: Equatable, Sendable {
    public let isSubscribed: Bool

    public init(isSubscribed: Bool = false) {
        self.isSubscribed = isSubscribed
    }
}

/// Asking for the paywall from inside the reader.
public struct ReaderPremiumRequest: Sendable {
    /// Why it was raised. One case today — the four study rows of the verse menu — but the
    /// reason travels so the shell can log it and so `isWired` can be told from "wired for
    /// something else", the same shape `RequestPremiumAction.Reason` has.
    public enum Reason: String, Sendable, CaseIterable {
        /// Explain Easier, Original Language, Deeper Study or Related Verses, tapped by a
        /// free reader. Deep Study is premium outright, and these are Deep Study's content.
        case verseMenuStudy
    }

    public typealias Handler = @MainActor @Sendable (Reason) -> Void

    private let handler: Handler?

    public init(_ handler: Handler? = nil) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction(_ reason: Reason) {
        handler?(reason)
    }

    public var isWired: Bool {
        handler != nil
    }
}

// MARK: - Deep Study

/// Opening Deep Study on a study unit key (`"2:255"`, `"94:5-6"`).
///
/// The shell wires this straight onto `Router.openDeepStudy(key:)` — the same call the
/// Discover card's "Deep study >" and the `scrollthequran://study/…` deep link make — so the
/// reader opens the one Deep Study screen rather than a second copy of it. `meaning` is the
/// first section of that screen, so the brief's "anchored at meaning" is its top: there is no
/// anchor to pass.
public struct OpenDeepStudyAction: Sendable {
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

// MARK: - Environment

private struct ReaderPremiumKey: EnvironmentKey {
    static let defaultValue = ReaderPremium()
}

private struct ReaderPremiumRequestKey: EnvironmentKey {
    static let defaultValue = ReaderPremiumRequest()
}

private struct OpenDeepStudyKey: EnvironmentKey {
    static let defaultValue = OpenDeepStudyAction()
}

public extension EnvironmentValues {
    /// Injected by `AppShell` from the one `Commerce` store. Absent means the free tier.
    var readerPremium: ReaderPremium {
        get { self[ReaderPremiumKey.self] }
        set { self[ReaderPremiumKey.self] = newValue }
    }

    /// Injected by `AppShell` as `ReaderPremiumRequest { env.gate.request(.deepStudy) }`.
    var requestReaderPremium: ReaderPremiumRequest {
        get { self[ReaderPremiumRequestKey.self] }
        set { self[ReaderPremiumRequestKey.self] = newValue }
    }

    /// Injected by `AppShell` as `OpenDeepStudyAction { router?.openDeepStudy(key: $0) }`.
    var openDeepStudy: OpenDeepStudyAction {
        get { self[OpenDeepStudyKey.self] }
        set { self[OpenDeepStudyKey.self] = newValue }
    }
}
