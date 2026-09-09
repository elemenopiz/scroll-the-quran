import Testing
@testable import StudyContent

@Test("StudyContent module is linked and identifies itself")
func StudyContentModuleIdentifiesItself() {
    #expect(StudyContentModule.moduleName == "StudyContent")
}
