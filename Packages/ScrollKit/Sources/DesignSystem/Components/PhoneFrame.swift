import SwiftUI

/// The device mockup the onboarding slides show screenshots inside: a black bezel with
/// a light rim, a Dynamic Island cut-out and the side buttons. Measured on
/// onboarding-slide2 — 740 px outer, 665 px screen, so a 10 pt bezel — and scaled from
/// `screenWidth`, which defaults to the reference's 222 pt.
public struct PhoneFrame<Content: View>: View {
    private let screenWidth: CGFloat
    private let content: Content

    public init(screenWidth: CGFloat = Metrics.phoneScreenWidth, @ViewBuilder content: () -> Content) {
        self.screenWidth = screenWidth
        self.content = content()
    }

    /// The mockup renders a 393x852 pt screen, so everything inside scales by this.
    public var contentScale: CGFloat {
        screenWidth / 393
    }

    private var screenHeight: CGFloat {
        screenWidth / Metrics.phoneScreenAspect
    }

    private var bezel: CGFloat {
        Metrics.phoneBezel * (screenWidth / Metrics.phoneScreenWidth)
    }

    private var outerRadius: CGFloat {
        screenWidth * 0.19
    }

    public var body: some View {
        content
            .frame(width: screenWidth, height: screenHeight)
            .clipShape(.rect(cornerRadius: outerRadius - bezel, style: .continuous))
            .overlay(alignment: .top) { island }
            .padding(bezel)
            .background {
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: max(1, bezel * 0.18))
                    }
            }
            .overlay(alignment: .leading) { sideButtons }
            .accessibilityHidden(true)
    }

    private var island: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: screenWidth * 0.28, height: screenWidth * 0.082)
            .padding(.top, screenWidth * 0.03)
    }

    private var sideButtons: some View {
        VStack(spacing: screenWidth * 0.035) {
            Capsule().frame(width: bezel * 0.3, height: screenWidth * 0.06)
            Capsule().frame(width: bezel * 0.3, height: screenWidth * 0.1)
            Capsule().frame(width: bezel * 0.3, height: screenWidth * 0.1)
        }
        .foregroundStyle(Color.white.opacity(0.25))
        .offset(x: -bezel * 0.15, y: -screenHeight * 0.14)
    }
}

#Preview("PhoneFrame light") {
    PhoneFramePreviews().preferredColorScheme(.light)
}

#Preview("PhoneFrame dark") {
    PhoneFramePreviews().preferredColorScheme(.dark)
}

private struct PhoneFramePreviews: View {
    var body: some View {
        PhoneFrame {
            VStack(spacing: Spacing.xl) {
                Spacer()
                VerseText(
                    arabic: VersePreviewFixture.shortArabic,
                    english: VersePreviewFixture.shortEnglish,
                    size: .discover
                )
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
