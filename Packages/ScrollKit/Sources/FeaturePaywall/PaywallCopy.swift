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
    }

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
}
