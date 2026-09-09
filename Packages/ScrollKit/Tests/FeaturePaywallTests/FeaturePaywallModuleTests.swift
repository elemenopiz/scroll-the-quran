@testable import FeaturePaywall
import Testing

@Test("FeaturePaywall module is linked and identifies itself")
func featurePaywallModuleIdentifiesItself() {
    #expect(FeaturePaywallModule.moduleName == "FeaturePaywall")
}
