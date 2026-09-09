import Testing
@testable import AppShell

@Test("AppShell module is linked and identifies itself")
func AppShellModuleIdentifiesItself() {
    #expect(AppShellModule.moduleName == "AppShell")
}
