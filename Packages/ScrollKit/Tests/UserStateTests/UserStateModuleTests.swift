import Testing
@testable import UserState

@Test("UserState module is linked and identifies itself")
func userStateModuleIdentifiesItself() {
    #expect(UserStateModule.moduleName == "UserState")
}
