import DesignSystem
import SwiftUI

/// **Placeholder screen art.** Stand-in for real captures of our own Reader, Plans,
/// Discover and Deep Study screens.
///
/// It reproduces the *geometry and tone distribution* of the reference mockups so the
/// slide snapshots are meaningful, not the content. The remaining slide RMSE lives
/// here: `.build/snapshots/onboarding-slide2-diff.png` shows the headline, the frame
/// and the call to action landing on the reference, with the residue entirely inside
/// the phone window.
///
/// **Why it is still a placeholder.** Those screens now exist — `FeatureReader`,
/// `FeatureHome` and `FeatureDiscover` all shipped, and `--screenshot reader` /
/// `home` / `discover` / `plans-sheet` are live routes. Both ways of using them are
/// blocked on the same frozen file:
///
/// - Rendering them directly needs `FeatureOnboarding` to depend on those targets.
///   `Package.swift` gives it `DesignSystem` and `UserState` only.
/// - Shipping PNGs from a `Tools/snapshot/render-mockups.sh` needs a
///   `resources: [.process("Resources")]` rule on this target, which that same file
///   does not declare — SwiftPM leaves an undeclared PNG unbundled.
///
/// `Package.swift` is frozen after Phase 1 and outside this task's ownership, so this
/// is a note rather than an edit. Unfreeze either line and the swap is local to this
/// file: `blocks` becomes an `Image`, and nothing else in the module changes.
struct MockupArt: View {
    let mockup: OnboardingContent.Mockup
    let scale: ReferenceScale

    private var size: CGSize {
        CGSize(
            width: scale.width(OnboardingMetrics.phoneScreenSize.width),
            height: scale.height(OnboardingMetrics.phoneScreenSize.height)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(blocks) { block in
                RoundedRectangle(cornerRadius: scale.width(block.radius), style: .continuous)
                    .fill(block.tone.color)
                    .frame(width: scale.width(block.rect.width), height: scale.height(block.rect.height))
                    .offset(x: scale.width(block.rect.minX), y: scale.height(block.rect.minY))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(base)
    }

    private var base: some View {
        (mockup == .discover || mockup == .deepstudy ? Color.rowBackground : Color.appBackgroundFlat)
            .frame(width: size.width, height: size.height)
    }

    private var blocks: [MockBlock] {
        switch mockup {
        case .reader: MockBlock.reader
        case .plans: MockBlock.plans
        case .discover: MockBlock.discover
        case .deepstudy: MockBlock.deepStudy
        }
    }
}

/// One rounded rectangle of placeholder art, in the 228 x 478 pt mock screen space.
struct MockBlock: Identifiable {
    enum Tone {
        case dim, wash, card, line, lineStrong, dark, photo, accent

        var color: Color {
            switch self {
            case .dim: Color.textTertiary.opacity(0.38)
            case .wash: Color.rowBackground
            case .card: Color.cardBackground
            case .line: Color.textTertiary.opacity(0.32)
            case .lineStrong: Color.textPrimary.opacity(0.72)
            case .dark: Color.pillFill
            case .photo: Color.textPrimary.opacity(0.72)
            case .accent: Color.ratingStar
            }
        }
    }

    let id = UUID()
    let rect: CGRect
    let radius: CGFloat
    let tone: Tone

    init(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat, _ tone: Tone) {
        rect = CGRect(x: x, y: y, width: w, height: h)
        self.radius = radius
        self.tone = tone
    }

    /// Text lines: `count` bars of decreasing width, centred or leading aligned.
    static func lines(
        x: CGFloat, y: CGFloat, widths: [CGFloat], height: CGFloat = 6,
        pitch: CGFloat = 12, tone: Tone = .line, centred: Bool = false
    ) -> [MockBlock] {
        widths.enumerated().map { index, width in
            let originX = centred ? x + (widths[0] - width) / 2 : x
            return MockBlock(originX, y + CGFloat(index) * pitch, width, height, height / 2, tone)
        }
    }

    /// A four-item tab bar strip across the bottom of a mock screen.
    static let tabBar: [MockBlock] = {
        var blocks = [MockBlock(0, 436, 228, 42, 0, .card)]
        for index in 0 ..< 4 {
            let x = 22 + CGFloat(index) * 52
            blocks.append(MockBlock(x + 6, 446, 14, 14, 3, .line))
            blocks.append(MockBlock(x, 466, 26, 5, 2.5, .line))
        }
        return blocks
    }()
}
