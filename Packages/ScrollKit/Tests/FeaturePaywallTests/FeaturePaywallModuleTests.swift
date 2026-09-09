import Testing
@testable import FeaturePaywall

@Test("FeaturePaywall module is linked and identifies itself")
func FeaturePaywallModuleIdentifiesItself() {
    #expect(FeaturePaywallModule.moduleName == "FeaturePaywall")
}
