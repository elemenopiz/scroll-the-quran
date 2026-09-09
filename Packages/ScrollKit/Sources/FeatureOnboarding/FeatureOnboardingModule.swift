import Foundation

/// Marker for the `FeatureOnboarding` module. Real types land in later phases; this keeps the
/// target non-empty so the package builds and the module has something to test.
public enum FeatureOnboardingModule {
    public static let moduleName = "FeatureOnboarding"
}
