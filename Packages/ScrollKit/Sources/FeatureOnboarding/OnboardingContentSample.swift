import Foundation

/// Sample copy for SwiftUI previews and host-side unit tests, where the app bundle
/// (and therefore `Content/onboarding.json`) is not available.
///
/// **The shipped strings live in `Content/onboarding.json`** — this is a stand-in with
/// the same shape, not a second source of truth. `OnboardingContentTests` checks the
/// real file against the shape asserted here.
public extension OnboardingContent {
    static let sample = OnboardingContent(
        version: 2,
        hook: Hook(
            headlineMarkdown: "The average Muslim will spend ***2+ hours today*** scrolling social media.",
            headline: [
                Span(text: "The average Muslim will spend ", style: .regular),
                Span(text: "2+ hours today", style: .boldItalic),
                Span(text: " scrolling social media.", style: .regular),
            ],
            subheadline: "Let's give some of that time back to Allah.",
            primaryCTA: "Continue",
            secondaryCTA: "I already signed up on the web",
            placeholder: true,
            placeholderNote: "Sample copy."
        ),
        signIn: SignIn(
            title: "Sign in",
            body: "Sign in with Apple so your streak, notes and saved verses follow you to your other devices.",
            appleButtonLabel: "Sign in with Apple",
            emailLabel: "Or use your email address",
            emailPlaceholder: "you@example.com",
            emailFootnote: "Stored on this device only. We do not email you.",
            recoverCTA: "Can't sign in? Recover Access",
            recoverMailto: "support@scrollthequran.app",
            recoverSubject: "Recover my Scroll the Quran access",
            skipCTA: "Not now"
        ),
        slides: [
            Slide(
                id: "onboarding-slide1", titleLines: 2, eyebrow: "Read",
                title: "What if scrolling actually fed your heart?",
                body: "The Quran, one ayah to a screen, in clear modern English.",
                mockup: .reader
            ),
            Slide(
                id: "onboarding-slide2", titleLines: 3, eyebrow: "Plans",
                title: "Reading the whole Quran feels impossible, until now.",
                body: "A juz a day through Ramadan, or Juz Amma one surah at a time.",
                mockup: .plans
            ),
            Slide(
                id: "onboarding-slide3", titleLines: 2, eyebrow: "Discover",
                title: "Every ayah has a story you have not heard.",
                body: "A daily feed of ayat with the context that makes them land.",
                mockup: .discover
            ),
            Slide(
                id: "onboarding-slide4", titleLines: 2, eyebrow: "Study",
                title: "Go deeper into any ayah than ever before.",
                body: "Meaning, context of revelation, key Arabic terms, and one thing to apply.",
                mockup: .deepstudy
            ),
        ],
        reviews: Reviews(
            title: "Lives are being changed.",
            subtitle: "Join {{installCount}} Muslims coming back to the Quran.",
            subtitleWithoutCount: "Join Muslims coming back to the Quran.",
            ratingValue: "4.8",
            ratingCount: "{{reviewCount}}",
            ratingSuffix: "reviews",
            primaryCTA: "Continue",
            placeholder: true,
            placeholderNote: "Sample copy.",
            cards: [
                Reviews.Card(
                    title: "Changed my mornings",
                    body: "I used to open the same three apps before getting out of bed. Now I read one ayah first. "
                        + "It sounds small and it has not been small.",
                    author: "Placeholder review", stars: 5, placeholder: true
                ),
                Reviews.Card(
                    title: "The context is the thing",
                    body: "I have read translations for years and always stopped at the words. "
                        + "Having the background right there is what made it stick.",
                    author: "Placeholder review", stars: 5, placeholder: true
                ),
                Reviews.Card(
                    title: "Finished my first plan",
                    body: "Juz Amma, one surah a day. First time I have finished anything like this "
                        + "without falling off in week two.",
                    author: "Placeholder review", stars: 5, placeholder: true
                ),
            ]
        ),
        legal: Legal(
            terms: "Terms", privacy: "Privacy", alreadySubscribed: "Already Subscribed?",
            restore: "Restore Purchases", translationNotice: "Translation by Talal Itani, ClearQuran.com"
        )
    )
}
