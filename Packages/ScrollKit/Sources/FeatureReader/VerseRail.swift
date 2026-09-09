import DesignSystem
import SwiftUI

/// The dashed rail down the left edge: one dash per ayah, a solid white indicator on the one
/// being read with its number beside it, and the surah's last ayah number pinned at the foot.
/// Tapping or dragging anywhere along it jumps, with a haptic tick per ayah crossed.
///
/// The dashes are drawn in a single `Canvas` rather than as 286 views: Al-Baqarah would
/// otherwise put 286 shapes into every layout pass of a paging scroll view.
struct VerseRail: View {
    let ayahCount: Int
    let currentAyah: Int
    /// Called while the finger is down, once per ayah crossed. Returns true when the ayah
    /// actually changed, which is what drives the haptic tick.
    let onScrub: (Int) -> Bool
    let onCommit: () -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let rail = VerseRailGeometry(ayahCount: ayahCount, height: proxy.size.height)
            ZStack(alignment: .topLeading) {
                track(rail)
                indicator(rail)
                currentNumber(rail)
                if rail.showsBottomNumber(forAyah: currentAyah) {
                    lastNumber(rail)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        _ = onScrub(rail.ayah(atY: value.location.y))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onCommit()
                    }
            )
        }
        .frame(width: ReaderMetrics.railHitWidth)
        // One tick per ayah crossed, and only while the finger is down: `sensoryFeedback`
        // reuses the engine instead of allocating a generator per tick down a 286-ayah rail.
        .sensoryFeedback(trigger: currentAyah) { _, _ in isDragging ? .selection : nil }
        .accessibilityElement()
        .accessibilityIdentifier("reader.rail")
        .accessibilityLabel("Ayah \(currentAyah) of \(ayahCount)")
        .accessibilityValue("\(currentAyah)")
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? currentAyah + 1 : currentAyah - 1
            _ = onScrub(min(max(next, 1), ayahCount))
            onCommit()
        }
    }

    /// Every ayah's dash except the current one, which the indicator covers.
    ///
    /// `progressTrack` rather than a colour matched exactly to the reference's `#252527`:
    /// the nearest token by dark value (`crossRefChipBackground`) is `#F3F3F4` in light, which
    /// disappears against the `#FAFAFC` page. A track is what this is, and the token reads in
    /// both appearances; on a 3 pt line the dark-side difference is invisible.
    private func track(_ rail: VerseRailGeometry) -> some View {
        Canvas { context, _ in
            let width = ReaderMetrics.railTrackWidth
            let x = ReaderMetrics.railCentreX - width / 2
            for ayah in 1 ... max(1, ayahCount) {
                let rect = CGRect(x: x, y: rail.origin(ofAyah: ayah), width: width, height: rail.dashLength)
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(.progressTrack))
            }
        }
        .allowsHitTesting(false)
    }

    /// The solid indicator: 15 px (5 pt) wide against the 9 px track, in `textPrimary`.
    private func indicator(_ rail: VerseRailGeometry) -> some View {
        Capsule(style: .continuous)
            .fill(Color.textPrimary)
            .frame(width: ReaderMetrics.railIndicatorWidth, height: rail.dashLength)
            .offset(
                x: ReaderMetrics.railCentreX - ReaderMetrics.railIndicatorWidth / 2,
                y: rail.origin(ofAyah: currentAyah)
            )
            .animation(isDragging ? nil : .easeOut(duration: 0.18), value: currentAyah)
            .allowsHitTesting(false)
    }

    /// The number beside the indicator, vertically centred on its dash.
    private func currentNumber(_ rail: VerseRailGeometry) -> some View {
        number(currentAyah, colour: .textSecondary)
            .offset(x: ReaderMetrics.railNumberLeading, y: rail.centre(ofAyah: currentAyah) - numberHeight / 2)
            .animation(isDragging ? nil : .easeOut(duration: 0.18), value: currentAyah)
            .allowsHitTesting(false)
    }

    /// The surah's length, pinned to the last dash.
    private func lastNumber(_ rail: VerseRailGeometry) -> some View {
        number(ayahCount, colour: .textTertiary)
            .offset(x: ReaderMetrics.railNumberLeading, y: rail.centre(ofAyah: ayahCount) - numberHeight / 2)
            .allowsHitTesting(false)
    }

    private func number(_ value: Int, colour: Color) -> some View {
        Text("\(value)")
            .font(.body(ReaderMetrics.railNumberSize, weight: .semibold))
            .foregroundStyle(colour)
            .frame(height: numberHeight)
            .accessibilityHidden(true)
    }

    private var numberHeight: CGFloat {
        ReaderMetrics.railNumberSize + Spacing.xs
    }
}

#Preview("Verse rail") {
    VerseRail(ayahCount: 21, currentAyah: 1, onScrub: { _ in false }, onCommit: {})
        .frame(height: 626)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
