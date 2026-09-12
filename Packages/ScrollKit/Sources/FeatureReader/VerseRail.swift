import DesignSystem
import SwiftUI

/// The dashed rail down the left edge: one dash per ayah, a solid white indicator on the one
/// being read with its number beside it, and the surah's last ayah number pinned at the foot.
/// Tapping or dragging anywhere along it jumps, with a haptic tick per ayah crossed.
///
/// The dashes are drawn in a single `Canvas` rather than as 286 views: Al-Baqarah would
/// otherwise put 286 shapes into every layout pass of a paging scroll view.
struct VerseRail: View {
    /// The open surah's number, for the scrub preview's "2:120".
    let surah: Int
    let ayahCount: Int
    let currentAyah: Int
    /// Called while the finger is down, once per ayah crossed. Returns true when the ayah
    /// actually changed, which is what drives the haptic tick.
    ///
    /// Phase 4j: this moves the rail's own state and nothing else. It must never move the
    /// pager — dozens of writes a second into `.scrollPosition(id:)` interrupt each other and
    /// the last one can settle between two pages. The jump happens once, on `onCommit`.
    let onScrub: (Int) -> Bool
    let onCommit: () -> Void

    @State private var isDragging = false
    /// Audit A11Y-4. The rail animates on every ayah crossed — continuously, while reading,
    /// on the app's most-used screen — and was the one place in the reader that never asked.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `nil` while the finger is down (the indicator must track it exactly) and for a
    /// reader who has asked for less motion.
    private var scrubAnimation: Animation? {
        isDragging || reduceMotion ? nil : .easeOut(duration: 0.18)
    }

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
                if isDragging {
                    preview(rail)
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
            .animation(scrubAnimation, value: currentAyah)
            .allowsHitTesting(false)
    }

    /// The number beside the indicator, vertically centred on its dash.
    private func currentNumber(_ rail: VerseRailGeometry) -> some View {
        number(currentAyah, colour: .textSecondary)
            .offset(x: ReaderMetrics.railNumberLeading, y: rail.centre(ofAyah: currentAyah) - numberHeight / 2)
            .animation(scrubAnimation, value: currentAyah)
            .allowsHitTesting(false)
    }

    /// The live preview while the finger is down: the reference the reader will land on.
    ///
    /// Clamped into the rail so a scrub to ayah 1 or to the last ayah cannot push it up
    /// under the toolbar or down over the tab bar.
    private func preview(_ rail: VerseRailGeometry) -> some View {
        Text("\(surah):\(currentAyah)")
            .font(.body(ReaderMetrics.railPreviewSize, weight: .semibold))
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, ReaderMetrics.railPreviewPaddingH)
            .padding(.vertical, ReaderMetrics.railPreviewPaddingV)
            .background(Color.chipBackground, in: Capsule(style: .continuous))
            .frame(height: previewHeight)
            .offset(
                x: ReaderMetrics.railPreviewLeading,
                y: clamp(rail.centre(ofAyah: currentAyah) - previewHeight / 2, in: rail, height: previewHeight)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    /// The surah's length, pinned to the last dash.
    private func lastNumber(_ rail: VerseRailGeometry) -> some View {
        number(ayahCount, colour: .textTertiaryReadable)
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

    private var previewHeight: CGFloat {
        ReaderMetrics.railPreviewSize + 2 * ReaderMetrics.railPreviewPaddingV + Spacing.xs
    }

    /// Keeps a label inside the rail's own span. The numbers are deliberately *not* clamped:
    /// at 286 ayat the "1" rides 5.9 pt above the rail, which `VerseRailGeometryTests`
    /// proves still clears the toolbar by 9 pt — and clamping it would move the pixels the
    /// `reader-dark` capture is scored against.
    private func clamp(_ y: CGFloat, in rail: VerseRailGeometry, height: CGFloat) -> CGFloat {
        min(max(y, 0), max(0, rail.height - height))
    }
}

#Preview("Verse rail") {
    VerseRail(surah: 5, ayahCount: 21, currentAyah: 1, onScrub: { _ in false }, onCommit: {})
        .frame(height: 626)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
