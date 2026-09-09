import Foundation

/// Every string the onboarding funnel shows, decoded from `Content/onboarding.json`.
///
/// The file ships inside the app bundle as a folder reference (`Content/onboarding.json`),
/// so `FeatureOnboarding` reads it out of `Bundle.main` rather than owning a resource of
/// its own. Copy is never hard-coded in a view.
public struct OnboardingContent: Equatable, Sendable, Codable {
    public let version: Int
    public let hook: Hook
    public let signIn: SignIn
    public let slides: [Slide]
    public let reviews: Reviews
    public let legal: Legal

    // MARK: - Hook

    public struct Hook: Equatable, Sendable, Codable {
        /// The headline as Markdown; `***span***` marks the bold-italic run.
        /// Kept alongside `headline` so either representation can drive the view.
        public let headlineMarkdown: String
        /// The same headline pre-split into styled spans.
        public let headline: [Span]
        public let subheadline: String
        public let primaryCTA: String
        public let secondaryCTA: String
        public let placeholder: Bool
        public let placeholderNote: String
    }

    /// A run of headline text with one style applied to it.
    public struct Span: Equatable, Sendable, Codable {
        public enum Style: String, Equatable, Sendable, Codable {
            case regular
            case boldItalic
        }

        public let text: String
        public let style: Style

        public init(text: String, style: Style) {
            self.text = text
            self.style = style
        }
    }

    // MARK: - Sign in

    public struct SignIn: Equatable, Sendable, Codable {
        public let title: String
        public let body: String
        public let appleButtonLabel: String
        public let emailLabel: String
        public let emailPlaceholder: String
        public let emailFootnote: String
        public let recoverCTA: String
        public let recoverMailto: String
        public let recoverSubject: String
        public let skipCTA: String

        /// `mailto:` URL behind "Can't sign in? Recover Access". No network call, no web view.
        public var recoverURL: URL? {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = recoverMailto
            components.queryItems = [URLQueryItem(name: "subject", value: recoverSubject)]
            return components.url
        }
    }

    // MARK: - Slides

    public struct Slide: Equatable, Sendable, Codable, Identifiable {
        public let id: String
        public let eyebrow: String
        public let title: String
        public let body: String
        /// Which of our own screens the phone-frame mockup shows.
        public let mockup: Mockup
    }

    public enum Mockup: String, Equatable, Sendable, Codable, CaseIterable {
        case reader
        case plans
        case discover
        case deepstudy
    }

    // MARK: - Reviews

    public struct Reviews: Equatable, Sendable, Codable {
        public let title: String
        /// Contains `{{installCount}}`; only rendered when a real count is injected.
        public let subtitle: String
        /// The honest wording used when we have no number to show.
        public let subtitleWithoutCount: String
        public let ratingValue: String
        public let ratingCount: String
        public let ratingSuffix: String
        public let primaryCTA: String
        public let placeholder: Bool
        public let placeholderNote: String
        public let cards: [Card]

        public struct Card: Equatable, Sendable, Codable, Identifiable {
            public let title: String
            public let body: String
            public let author: String
            public let stars: Int
            public let placeholder: Bool

            public var id: String {
                title
            }
        }
    }

    public struct Legal: Equatable, Sendable, Codable {
        public let terms: String
        public let privacy: String
        public let alreadySubscribed: String
        public let restore: String
        public let translationNotice: String
    }
}

// MARK: - Loading

public extension OnboardingContent {
    enum LoadError: Error, Equatable {
        case notFound
    }

    /// Decodes `Content/onboarding.json` out of a bundle. The app bundle carries
    /// `Content/` as a folder reference; tests hand in a file URL instead.
    static func load(from bundle: Bundle) throws -> OnboardingContent {
        let url = bundle.url(forResource: "onboarding", withExtension: "json", subdirectory: "Content")
            ?? bundle.url(forResource: "onboarding", withExtension: "json")
        guard let url else { throw LoadError.notFound }
        return try load(contentsOf: url)
    }

    static func load(contentsOf url: URL) throws -> OnboardingContent {
        try JSONDecoder().decode(OnboardingContent.self, from: Data(contentsOf: url))
    }

    /// What the app renders: the bundled copy, or the built-in sample when the
    /// resource is missing (SwiftUI previews and host-side unit tests).
    static var bundled: OnboardingContent {
        (try? load(from: .main)) ?? .sample
    }
}
