import Foundation

/// Marker for the `FeatureCommunity` module. Real types land in later phases; this keeps the
/// target non-empty so the package builds and the module has something to test.
public enum FeatureCommunityModule {
    public static let moduleName = "FeatureCommunity"
}
