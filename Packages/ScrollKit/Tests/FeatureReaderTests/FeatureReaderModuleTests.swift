import Testing
@testable import FeatureReader

@Test("FeatureReader module is linked and identifies itself")
func FeatureReaderModuleIdentifiesItself() {
    #expect(FeatureReaderModule.moduleName == "FeatureReader")
}
