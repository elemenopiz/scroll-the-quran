@testable import QuranData
import Testing

@Test("QuranData module is linked and identifies itself")
func quranDataModuleIdentifiesItself() {
    #expect(QuranDataModule.moduleName == "QuranData")
}
