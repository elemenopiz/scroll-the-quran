import DesignSystem
import SwiftUI
import WidgetKit

@main
struct VerseWidgetBundle: WidgetBundle {
    init() {
        DesignSystem.registerFonts()
    }

    var body: some Widget {
        VerseWidget()
    }
}
