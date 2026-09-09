@testable import StudyContent
import Testing

@Test("StudyContent module is linked and identifies itself")
func studyContentModuleIdentifiesItself() {
    #expect(StudyContentModule.moduleName == "StudyContent")
}
