import Testing
@testable import FeatureHome

@Test("FeatureHome module is linked and identifies itself")
func FeatureHomeModuleIdentifiesItself() {
    #expect(FeatureHomeModule.moduleName == "FeatureHome")
}
