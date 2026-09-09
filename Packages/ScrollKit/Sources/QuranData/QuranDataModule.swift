import Foundation

/// Marker for the `QuranData` module. Real types land in later phases; this keeps the
/// target non-empty so the package builds and the module has something to test.
public enum QuranDataModule {
    public static let moduleName = "QuranData"
}
