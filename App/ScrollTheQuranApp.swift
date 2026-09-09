import AppShell
import DesignSystem
import SwiftUI

@main
struct ScrollTheQuranApp: App {
    init() {
        DesignSystem.registerFonts()
        // `--screenshot widget-gallery` renders the widget's own views. They are compiled
        // into this target from `Widget/Shared`, not into `AppShell` (an app extension has
        // no business linking the whole shell), so the app hands the shell the factory.
        WidgetGalleryProvider.make = { AnyView(WidgetGalleryScreen()) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
