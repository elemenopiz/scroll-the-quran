import SwiftUI

/// Phase 1 stand-in for a real screen. Renders the screen id so snapshots and
/// UI tests can tell the tabs apart before the feature modules exist.
/// Restyled onto `DesignSystem` tokens in step 4.
public struct PlaceholderScreen: View {
    private let screenID: String
    private let title: String
    private let systemImage: String

    public init(screenID: String, title: String, systemImage: String) {
        self.screenID = screenID
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        ZStack {
            Color(uiColorNamed: .background).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 28, design: .serif))
                Text(screenID)
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("screen.id")
            }
        }
        .accessibilityIdentifier("screen.\(screenID)")
    }
}

/// Small shim so the placeholder compiles on the macOS host too.
enum PlatformColor { case background }

extension Color {
    init(uiColorNamed _: PlatformColor) {
        #if canImport(UIKit)
            self = Color(.systemBackground)
        #else
            self = Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

#Preview("Placeholder") {
    PlaceholderScreen(screenID: "home", title: "Home", systemImage: "house")
}
