import Foundation

/// Every fixed string on the paywall and the gift screens. Kept together so the copy can
/// be reviewed (and later localised) without reading four view bodies.
enum PaywallCopy {
    static let headline = ["How your free", "trial works"]

    struct TimelineStep: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let body: String
    }

    static let timeline: [TimelineStep] = [
        TimelineStep(
            id: "today",
            symbol: "lock.open.fill",
            title: "Today",
            body: "Open the Quran like never before. Full access, everything unlocked"
        ),
        TimelineStep(
            id: "day5",
            symbol: "bell.fill",
            title: "Day 5",
            body: "A reminder with your week in the Book"
        ),
        TimelineStep(
            id: "day7",
            symbol: "checkmark",
            title: "Day 7",
            body: "Pick a reading plan and continue verse by verse"
        ),
    ]

    static let noPaymentDueNow = "No payment due now"
    static let viewAllPlans = "View all plans"
    static let cancelAnytime = "Cancel anytime."
    /// The footer row. Every one of these is a working control: App Review guideline
    /// 3.1.2(a) requires a live Terms of Use and Privacy Policy link on a subscription
    /// purchase screen, so none of them may be decorative.
    enum LegalLink: String, CaseIterable, Identifiable {
        case terms = "Terms"
        case privacy = "Privacy"
        case alreadySubscribed = "Already Subscribed?"
        case restore = "Restore Purchases"

        var id: String {
            rawValue
        }

        var title: String {
            rawValue
        }

        /// Stable, space-free suffix for an accessibility identifier.
        var slug: String {
            switch self {
            case .terms: "terms"
            case .privacy: "privacy"
            case .alreadySubscribed: "alreadySubscribed"
            case .restore: "restore"
            }
        }
    }

    /// The gift offer's own footer. "Already Subscribed?" is dropped there — it means the
    /// same thing as Restore Purchases, and the gift screen has 393 pt to fit three live
    /// controls plus the renewal disclosure into.
    static let giftLegal: [LegalLink] = [.terms, .privacy, .restore]

    static var legal: [String] {
        LegalLink.allCases.map(\.title)
    }

    static let fullAccessTitle = "7-Days Full Access"
    static let monthlyPlanTitle = "Monthly plan"

    static let giftHeadline = ["A Gift is waiting for", "you!"]
    static let giftSubtitle = ["Claim it while it is available.", "We saved a special offer just for you."]
    static let giftReveal = "Tap Anywhere to reveal"
    static let oneTimeOffer = "One Time Offer"
    static let off = "OFF"
    static let neverAgain = "You will never see this again"
    static let luckyYou = "Lucky you!"
    static let startFreeTrial = "Start FREE trial"
    static let continueTitle = "Continue"
    /// Shown while a purchase is waiting on a family organiser (Ask to Buy).
    static let askToBuyPending = "Ask your family organiser to approve this purchase."
    /// Shown after the customer backs out of the App Store sheet. Deliberately not phrased
    /// as an error — nothing went wrong — but saying nothing at all is what made the button
    /// look broken (audit IAP-1).
    static let purchaseCancelled = "Purchase cancelled — you have not been charged."
    /// A restore that reached the App Store and found nothing to give back.
    static let nothingToRestore = "We could not find a purchase to restore on this Apple Account."
    /// A restore that could not reach the App Store at all.
    static let restoreFailed = "We could not reach the App Store. Please try again."
    /// Read out in place of the call to action's title while a purchase is in flight.
    static let purchaseInProgress = "Purchasing"
    /// The gift screen sells a real auto-renewing subscription, so its footnote says so in
    /// as many words rather than leaving it to "Cancel anytime" (guideline 3.1.2(a)).
    ///
    /// One word, because the whole footnote has to stay on one 393 pt line: the gift
    /// screen's footer band is 46 pt tall between the call to action and the home
    /// indicator, and the Terms / Privacy / Restore row takes the second line of it.
    /// Cancellation terms live behind that Terms link.
    static let autoRenewNote = "Auto-renews"
}
