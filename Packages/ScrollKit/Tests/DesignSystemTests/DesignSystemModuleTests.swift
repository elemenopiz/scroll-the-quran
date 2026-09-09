import Testing
@testable import DesignSystem

@Test("DesignSystem module is linked and identifies itself")
func DesignSystemModuleIdentifiesItself() {
    #expect(DesignSystemModule.moduleName == "DesignSystem")
}
