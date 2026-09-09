@testable import FeatureOnboarding
import Testing

@Test("FeatureOnboarding module is linked and identifies itself")
func featureOnboardingModuleIdentifiesItself() {
    #expect(FeatureOnboardingModule.moduleName == "FeatureOnboarding")
}
