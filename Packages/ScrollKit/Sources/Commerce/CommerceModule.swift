import Foundation

/// Marker for the `Commerce` module. Real types land in later phases; this keeps the
/// target non-empty so the package builds and the module has something to test.
public enum CommerceModule {
    public static let moduleName = "Commerce"
}
