import Testing
@testable import QuranData

@Test("QuranData module is linked and identifies itself")
func QuranDataModuleIdentifiesItself() {
    #expect(QuranDataModule.moduleName == "QuranData")
}
