import AppShell
import SwiftUI

/// The app's state machine: onboarding, then the paywall, then the one-time gift
/// offer if the paywall was dismissed, then the tab bar. Phase 1 renders labelled
/// placeholders for the first three; `FeatureOnboarding` and `FeaturePaywall`
/// replace them in Phase 3.
///
/// `--screenshot <id>` routes straight to a screen and `SCROLL_FIXED_DATE` pins
/// "today", so every screen is capturable headlessly and deterministically.
struct RootView: View {
    private let launch: LaunchOptions
    @State private var flow: RootFlowModel
    @State private var tabs: TabRootModel

    init(launch: LaunchOptions = .live) {
        self.launch = launch
        _flow = State(initialValue: RootFlowModel(launch: launch))
        _tabs = State(initialValue: TabRootModel(selection: launch.screenshot?.tab ?? .home))
    }

    var body: some View {
        content
            .environment(\.appToday, launch.fixedDate ?? Date())
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                tabs.handle(link)
            }
    }

    @ViewBuilder
    private var content: some View {
        if launch.screenshot?.screen == .gallery {
            GalleryScreen()
        } else {
            phaseContent
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch flow.phase {
        case .onboarding:
            stage(id: launch.screenshot?.screen.rawValue ?? "onboarding-hook",
                  title: "Onboarding",
                  systemImage: "sparkle")
        case .paywall:
            stage(id: launch.screenshot?.screen.rawValue ?? "paywall-trial",
                  title: "Paywall",
                  systemImage: "crown")
        case .gift:
            stage(id: launch.screenshot?.screen.rawValue ?? "gift-closed",
                  title: "One-time offer",
                  systemImage: "gift")
        case .tabs:
            TabRoot(model: tabs)
        }
    }

    private func stage(id: String, title: String, systemImage: String) -> some View {
        VStack(spacing: 24) {
            PlaceholderScreen(screenID: id, title: title, systemImage: systemImage)
            if !launch.isSnapshotRun {
                Button("Continue") { flow.advance() }
                    .accessibilityIdentifier("stage.continue")
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview("Root") {
    RootView(launch: LaunchOptions())
}
