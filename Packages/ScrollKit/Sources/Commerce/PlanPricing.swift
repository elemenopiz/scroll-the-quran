import Foundation

/// Every price string the paywall and the gift screens show, derived from a `StorePlan`.
///
/// All of it is pure arithmetic on `Decimal` so it is unit-testable without StoreKit.
/// Derived per-unit prices are rounded **down** to the cent, which is what the reference
/// app does: $29.99 / 12 = $2.4991 is shown as "$2.49", not "$2.50".
public enum PlanPricing {
    // MARK: - Lines

    /// "$29.99/year", "$4.99/month" — the store's own formatted price plus the period.
    public static func periodLine(_ plan: StorePlan) -> String {
        "\(plan.displayPrice)/\(plan.period.suffix)"
    }

    /// "($2.49/mo)" under the yearly price. `nil` for a plan that already bills monthly.
    public static func monthlyEquivalent(_ plan: StorePlan, locale: Locale = .current) -> String? {
        guard plan.period == .year else { return nil }
        let monthly = roundedDown(plan.annualisedPrice / 12)
        return "(\(format(monthly, currencyCode: plan.currencyCode, locale: locale))/mo)"
    }

    /// "$0.00/week" while a free trial is running, otherwise the annualised price per week
    /// ("$1.15/week" for a $4.99 month). This is the trailing figure on a plan card.
    public static func weeklyLine(_ plan: StorePlan, locale: Locale = .current) -> String {
        let amount = plan.introOffer == nil ? roundedDown(plan.annualisedPrice / 52) : 0
        return "\(format(amount, currencyCode: plan.currencyCode, locale: locale))/week"
    }

    /// The struck-through "compare at" price beside a discounted plan: the plan's own price
    /// doubled and pushed up to the next `.99`. $29.99 -> $59.99.
    public static func comparePrice(_ plan: StorePlan) -> Decimal {
        var doubled = plan.price * 2
        var rounded = Decimal()
        NSDecimalRound(&rounded, &doubled, 0, .up)
        return rounded - Decimal(string: "0.01")!
    }

    /// "$59.99" — `comparePrice` formatted.
    public static func compareLine(_ plan: StorePlan, locale: Locale = .current) -> String {
        format(comparePrice(plan), currencyCode: plan.currencyCode, locale: locale)
    }

    // MARK: - Badges

    /// The whole-percent saving going from `list` to `sale`, rounded to nearest.
    /// $59.99 -> $29.99 is 50; $29.99 -> $19.99 is 33.
    public static func savePercent(list: Decimal, sale: Decimal) -> Int {
        guard list > 0, sale >= 0, sale < list else { return 0 }
        var raw = (1 - sale / list) * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// "SAVE 50%" for the badge that overlaps the selected plan card.
    public static func saveBadge(_ plan: StorePlan) -> String {
        "SAVE \(savePercent(list: comparePrice(plan), sale: plan.price))%"
    }

    /// The discount of the gift plan against the standard plan, e.g. 33.
    public static func discountPercent(standard: StorePlan, offer: StorePlan) -> Int {
        savePercent(list: standard.price, sale: offer.price)
    }

    // MARK: - Trial copy

    /// "Redeem 7 days for $0.00" — the primary call to action.
    public static func redeemTitle(_ plan: StorePlan, locale: Locale = .current) -> String {
        guard let intro = plan.introOffer else { return "Continue" }
        let zero = format(0, currencyCode: plan.currencyCode, locale: locale)
        return "Redeem \(intro.freeDays) days for \(zero)"
    }

    /// "3 days free, then $19.99/year" — the footnote under the gift call to action.
    public static func trialFootnote(_ plan: StorePlan) -> String {
        guard let intro = plan.introOffer else { return periodLine(plan) }
        return "\(intro.freeDays) days free, then \(periodLine(plan))"
    }

    // MARK: - Helpers

    /// Truncates towards zero at two decimal places.
    static func roundedDown(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .down)
        return output
    }

    /// Currency formatting for amounts the store did not hand us pre-formatted.
    public static func format(_ amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }
}
