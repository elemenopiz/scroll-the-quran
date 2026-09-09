@testable import FeatureDiscover
import Testing

@Test("FeatureDiscover module is linked and identifies itself")
func featureDiscoverModuleIdentifiesItself() {
    #expect(FeatureDiscoverModule.moduleName == "FeatureDiscover")
}
