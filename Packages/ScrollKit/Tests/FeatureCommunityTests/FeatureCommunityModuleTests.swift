@testable import FeatureCommunity
import Testing

@Test("FeatureCommunity module is linked and identifies itself")
func featureCommunityModuleIdentifiesItself() {
    #expect(FeatureCommunityModule.moduleName == "FeatureCommunity")
}
