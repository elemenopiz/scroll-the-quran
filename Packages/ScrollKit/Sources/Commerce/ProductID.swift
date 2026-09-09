import Foundation

/// Every in-app product the app sells. Raw values match `Config/ScrollTheQuran.storekit`
/// and App Store Connect; nothing else in the app may spell a product identifier out.
public enum ProductID: String, CaseIterable, Sendable, Codable {
    /// The headline plan: one year, 7-day free trial.
    case yearly = "com.scrollthequran.yearly"
    /// The alternative on the "View all plans" sheet.
    case monthly = "com.scrollthequran.monthly"
    /// The one-time gift offer shown after the paywall is dismissed: 33% off, 3-day trial.
    case yearlyGift = "com.scrollthequran.yearly.gift"

    /// The subscription group every plan belongs to.
    public static let subscriptionGroupID = "21500001"

    public static var allRawValues: [String] {
        allCases.map(\.rawValue)
    }
}
