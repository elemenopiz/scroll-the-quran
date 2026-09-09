import SwiftUI

/// The Home reading-progress track: 30 px (10 pt) tall, full card width,
/// `Color.progressTrack` behind `Color.textPrimary`, both fully rounded.
public struct ProgressBar: View {
    private let value: Double
    private let height: CGFloat
    private let tint: Color

    /// `value` is clamped to 0...1, so callers can pass a raw ratio.
    public init(value: Double, height: CGFloat = Metrics.progressBarHeight, tint: Color = .textPrimary) {
        self.value = value
        self.height = height
        self.tint = tint
    }

    /// The fraction actually drawn: `value` clamped into 0...1, NaN treated as 0.
    var fraction: Double {
        ProgressBar.clamp(value)
    }

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    public var body: some View {
        // A leaf `GeometryReader` inside an explicit `.frame(height:)`: the fill has to
        // be a fraction of the *parent's* width, which `containerRelativeFrame` cannot
        // express (it measures the enclosing scroll view), and scaling a capsule would
        // distort its end caps.
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.progressTrack)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * fraction))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview("ProgressBar light") {
    ProgressBarPreviews().preferredColorScheme(.light)
}

#Preview("ProgressBar dark") {
    ProgressBarPreviews().preferredColorScheme(.dark)
}

private struct ProgressBarPreviews: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            ProgressBar(value: 0)
            ProgressBar(value: 0.008)
            ProgressBar(value: 0.42)
            ProgressBar(value: 1)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
