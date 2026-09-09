import AppShell
import DesignSystem
import SwiftUI

@main
struct ScrollTheQuranApp: App {
    init() {
        DesignSystem.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
