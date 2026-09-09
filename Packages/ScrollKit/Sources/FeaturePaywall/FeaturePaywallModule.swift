import Foundation

/// Marker for the `FeaturePaywall` module. Real types land in later phases; this keeps the
/// target non-empty so the package builds and the module has something to test.
public enum FeaturePaywallModule {
    public static let moduleName = "FeaturePaywall"
}
