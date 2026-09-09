@testable import Commerce
import Foundation
import Testing

private let us = Locale(identifier: "en_US")

@Suite("Price lines")
struct PlanPricingTests {
    @Test("The yearly plan prints the store's own price plus the period")
    func yearlyPeriodLine() {
        #expect(PlanPricing.periodLine(StoreCatalogue.yearly) == "$29.99/year")
        #expect(PlanPricing.periodLine(StoreCatalogue.monthly) == "$4.99/month")
        #expect(PlanPricing.periodLine(StoreCatalogue.gift) == "$19.99/year")
    }

    @Test("$29.99 a year reads as $2.49 a month, truncated rather than rounded up")
    func monthlyEquivalent() {
        #expect(PlanPricing.monthlyEquivalent(StoreCatalogue.yearly, locale: us) == "($2.49/mo)")
        #expect(PlanPricing.monthlyEquivalent(StoreCatalogue.gift, locale: us) == "($1.66/mo)")
    }

    @Test("A plan that already bills monthly has no monthly equivalent line")
    func noMonthlyEquivalentForMonthly() {
        #expect(PlanPricing.monthlyEquivalent(StoreCatalogue.monthly, locale: us) == nil)
    }

    @Test("The weekly figure is $0.00 while a free trial runs and annualised otherwise")
    func weeklyLine() {
        #expect(PlanPricing.weeklyLine(StoreCatalogue.yearly, locale: us) == "$0.00/week")
        #expect(PlanPricing.weeklyLine(StoreCatalogue.monthly, locale: us) == "$1.15/week")
    }

    @Test("A plan with no trial prices its own annual total per week")
    func weeklyLineWithoutTrial() throws {
        let plan = try StorePlan(
            id: .yearly,
            displayName: "Premium Yearly",
            displayPrice: "$29.99",
            price: #require(Decimal(string: "29.99")),
            period: .year
        )
        // 29.99 / 52 = 0.5767..., truncated to the cent.
        #expect(PlanPricing.weeklyLine(plan, locale: us) == "$0.57/week")
    }

    @Test("The compare-at price doubles the plan and lands on the next .99")
    func comparePrice() {
        #expect(PlanPricing.compareLine(StoreCatalogue.yearly, locale: us) == "$59.99")
        #expect(PlanPricing.compareLine(StoreCatalogue.monthly, locale: us) == "$9.99")
    }

    @Test("The yearly badge reads SAVE 50% and the gift card is 33% off")
    func savePercentages() {
        #expect(PlanPricing.saveBadge(StoreCatalogue.yearly) == "SAVE 50%")
        #expect(PlanPricing.discountPercent(standard: StoreCatalogue.yearly, offer: StoreCatalogue.gift) == 33)
    }

    @Test("Save percentage is zero when the sale price is not a discount")
    func savePercentGuards() {
        #expect(PlanPricing.savePercent(list: 10, sale: 10) == 0)
        #expect(PlanPricing.savePercent(list: 10, sale: 12) == 0)
        #expect(PlanPricing.savePercent(list: 0, sale: 0) == 0)
    }

    @Test("Call-to-action copy names the trial length and the price after it")
    func trialCopy() {
        #expect(PlanPricing.redeemTitle(StoreCatalogue.yearly, locale: us) == "Redeem 7 days for $0.00")
        #expect(PlanPricing.redeemTitle(StoreCatalogue.gift, locale: us) == "Redeem 3 days for $0.00")
        #expect(PlanPricing.redeemTitle(StoreCatalogue.monthly, locale: us) == "Continue")
        #expect(PlanPricing.trialFootnote(StoreCatalogue.gift) == "3 days free, then $19.99/year")
        #expect(PlanPricing.trialFootnote(StoreCatalogue.monthly) == "$4.99/month")
    }

    @Test("Rounding down never lifts a fraction to the next cent")
    func roundingDown() throws {
        #expect(try PlanPricing.roundedDown(#require(Decimal(string: "2.499"))) == Decimal(string: "2.49")!)
        #expect(try PlanPricing.roundedDown(#require(Decimal(string: "1.1515"))) == Decimal(string: "1.15")!)
        #expect(PlanPricing.roundedDown(0) == 0)
    }

    @Test("An annualised price is the plan price times its periods per year")
    func annualising() {
        #expect(StoreCatalogue.monthly.annualisedPrice == Decimal(string: "59.88")!)
        #expect(StoreCatalogue.yearly.annualisedPrice == Decimal(string: "29.99")!)
    }
}

@Suite("Product identifiers")
struct ProductIDTests {
    @Test("Identifiers match the StoreKit configuration file")
    func rawValues() {
        #expect(ProductID.yearly.rawValue == "com.scrollthequran.yearly")
        #expect(ProductID.monthly.rawValue == "com.scrollthequran.monthly")
        #expect(ProductID.yearlyGift.rawValue == "com.scrollthequran.yearly.gift")
        #expect(ProductID.allRawValues.count == 3)
    }

    @Test("Every product in Config/ScrollTheQuran.storekit is known to ProductID")
    func configurationFileMatchesCatalogue() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CommerceTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ScrollKit
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Config/ScrollTheQuran.storekit")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let groups = json?["subscriptionGroups"] as? [[String: Any]] ?? []
        let group = try #require(groups.first)
        #expect(group["id"] as? String == ProductID.subscriptionGroupID)
        let subscriptions = group["subscriptions"] as? [[String: Any]] ?? []
        let ids = Set(subscriptions.compactMap { $0["productID"] as? String })
        #expect(ids == Set(ProductID.allRawValues))

        // The fixture catalogue must quote the same prices as the configuration file.
        for subscription in subscriptions {
            let id = try #require(ProductID(rawValue: subscription["productID"] as? String ?? ""))
            let plan = try #require(StoreCatalogue.all.first { $0.id == id })
            #expect(subscription["displayPrice"] as? String == "\(plan.price)")
        }
    }
}
