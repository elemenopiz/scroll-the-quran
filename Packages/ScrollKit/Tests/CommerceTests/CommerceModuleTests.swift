import Testing
@testable import Commerce

@Test("Commerce module is linked and identifies itself")
func CommerceModuleIdentifiesItself() {
    #expect(CommerceModule.moduleName == "Commerce")
}
