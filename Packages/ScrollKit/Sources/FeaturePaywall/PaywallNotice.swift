import DesignSystem
import SwiftUI

/// The one thing the paywall has to say back after the customer taps a button.
///
/// Audit finding IAP-1: `PaywallModel` computed an error message, a pending message and an
/// in-flight flag, and **no view read any of them**. A declined card, a parental-controls
/// block, an ineligible offer and a restore that finds nothing all looked identical — the
/// button simply stopped responding. This is the single piece of state every purchase
/// surface now binds to, so a branch that says nothing cannot be added without noticing.
public enum PaywallNotice: Equatable, Sendable {
    /// Something failed. The customer may want to try again or change payment method.
    case error(String)
    /// Ask to Buy: the purchase is real but nothing is unlocked until it is approved.
    case pending(String)
    /// Neither: a cancellation, or a restore that found nothing.
    case info(String)

    public var text: String {
        switch self {
        case let .error(text), let .pending(text), let .info(text): text
        }
    }

    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    var symbol: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .pending: "clock.fill"
        case .info: "info.circle.fill"
        }
    }
}

/// The inline banner every paywall surface shows a `PaywallNotice` in.
///
/// Rendered only when there is something to say, so no capture in `Reference/` moves: the
/// snapshot routes never reach a failed, cancelled or pending purchase.
struct PaywallNoticeView: View {
    let notice: PaywallNotice
    /// The gift screens are a fixed warm-paper composition that does not follow the
    /// appearance, so they pass their own ink and paper rather than the tokens.
    var ink: Color = .textPrimary
    var mutedInk: Color = .textSecondary
    var paper: Color = .rowBackground
    var edge: Color = .divider
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: notice.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(notice.isError ? ink : mutedInk)
                .accessibilityHidden(true)

            Text(notice.text)
                .font(.geoRegular(13))
                .foregroundStyle(ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("paywall.notice.text")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(mutedInk)
                    // 44 pt hit target around a 12 pt glyph (audit A11Y-5).
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(y: -14)
            .accessibilityIdentifier("paywall.notice.dismiss")
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, 0)
        .padding(.vertical, Spacing.md)
        .background(paper, in: RoundedRectangle(cornerRadius: Radius.chip))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.chip)
                .strokeBorder(edge, lineWidth: Stroke.hairline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.notice")
    }
}

#Preview("Notices") {
    VStack(spacing: Spacing.lg) {
        PaywallNoticeView(notice: .error(PaywallCopy.restoreFailed), onDismiss: {})
        PaywallNoticeView(notice: .pending(PaywallCopy.askToBuyPending), onDismiss: {})
        PaywallNoticeView(notice: .info(PaywallCopy.purchaseCancelled), onDismiss: {})
    }
    .padding()
}
