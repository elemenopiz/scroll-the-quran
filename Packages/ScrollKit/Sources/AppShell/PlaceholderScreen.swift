import DesignSystem
import SwiftUI

/// Phase 1 stand-in for a real screen. Renders the screen id so snapshots and
/// UI tests can tell the tabs apart before the feature modules exist.
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
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(Color.textSecondary)
                Text(title)
                    .font(.serifDisplay(28))
                    .foregroundStyle(Color.textPrimary)
                Text(screenID)
                    .capsLabelStyle()
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("screen.\(screenID).label")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.\(screenID)")
    }
}

#Preview("Placeholder") {
    PlaceholderScreen(screenID: "home", title: "Home", systemImage: "house")
}
