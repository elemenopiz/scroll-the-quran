@testable import FeatureHome
import Testing

@Test("FeatureHome module is linked and identifies itself")
func featureHomeModuleIdentifiesItself() {
    #expect(FeatureHomeModule.moduleName == "FeatureHome")
}
