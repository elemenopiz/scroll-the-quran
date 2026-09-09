@testable import DesignSystem
import Testing

@Test("DesignSystem module is linked and identifies itself")
func designSystemModuleIdentifiesItself() {
    #expect(DesignSystem.moduleName == "DesignSystem")
}

@Test("Font registration is idempotent and reports what it registered")
func fontRegistrationIsIdempotent() {
    let first = DesignSystem.registerFonts()
    let second = DesignSystem.registerFonts()
    #expect(first == second)
    #expect(first.count == DesignSystem.bundledFontURLs.count)
}
