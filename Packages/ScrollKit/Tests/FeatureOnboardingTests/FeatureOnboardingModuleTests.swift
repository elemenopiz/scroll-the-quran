import Testing
@testable import FeatureOnboarding

@Test("FeatureOnboarding module is linked and identifies itself")
func FeatureOnboardingModuleIdentifiesItself() {
    #expect(FeatureOnboardingModule.moduleName == "FeatureOnboarding")
}
