@testable import Commerce
import Testing

@Test("Commerce module is linked and identifies itself")
func commerceModuleIdentifiesItself() {
    #expect(CommerceModule.moduleName == "Commerce")
}
