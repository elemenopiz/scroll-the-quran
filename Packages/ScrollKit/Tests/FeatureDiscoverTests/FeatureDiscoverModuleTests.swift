import Testing
@testable import FeatureDiscover

@Test("FeatureDiscover module is linked and identifies itself")
func FeatureDiscoverModuleIdentifiesItself() {
    #expect(FeatureDiscoverModule.moduleName == "FeatureDiscover")
}
