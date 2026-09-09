import Testing
@testable import FeatureCommunity

@Test("FeatureCommunity module is linked and identifies itself")
func FeatureCommunityModuleIdentifiesItself() {
    #expect(FeatureCommunityModule.moduleName == "FeatureCommunity")
}
