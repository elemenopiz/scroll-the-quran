@testable import FeatureReader
import Testing

@Test("FeatureReader module is linked and identifies itself")
func featureReaderModuleIdentifiesItself() {
    #expect(FeatureReaderModule.moduleName == "FeatureReader")
}
