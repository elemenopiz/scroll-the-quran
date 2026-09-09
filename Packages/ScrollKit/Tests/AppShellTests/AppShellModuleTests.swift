@testable import AppShell
import Testing

@Test("AppShell module is linked and identifies itself")
func appShellModuleIdentifiesItself() {
    #expect(AppShellModule.moduleName == "AppShell")
}
