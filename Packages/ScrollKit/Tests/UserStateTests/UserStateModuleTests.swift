import Testing
@testable import UserState

@Test("UserState module is linked and identifies itself")
func UserStateModuleIdentifiesItself() {
    #expect(UserStateModule.moduleName == "UserState")
}
