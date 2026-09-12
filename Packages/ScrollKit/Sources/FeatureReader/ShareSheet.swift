import DesignSystem
import QuranData
import SwiftUI

/// The card the share sheet hands over: the muted Arabic above the English, the reference,
/// and the attribution the translation's licence requires. Square, so it drops straight into
/// a story or a message without being re-cropped.
struct ShareCard: View {
    static let side = ReaderMetrics.shareCardSide

    let reference: String
    let arabic: String?
    let english: String
    let attribution: String

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: 0)
            VerseText(arabic: arabic, english: english, size: .deepStudy)
            Text(reference)
                .font(.body(ReaderMetrics.shareReferenceSize, weight: .semibold))
                .tracking(ReaderMetrics.referenceTracking)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
            Text(attribution)
                .font(.body(ReaderMetrics.shareAttributionSize))
                .foregroundStyle(Color.textTertiaryReadable)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.xxl)
        .frame(width: Self.side, height: Self.side)
        .background(Color.appBackgroundFlat)
    }
}

/// The share sheet: a preview of the card and a `ShareLink` carrying the rendered image.
///
/// `ImageRenderer` runs on the main actor and needs the bundled faces registered, which the
/// app does at launch; the render is done once when the sheet appears.
struct ShareSheetView: View {
    let reference: String
    let arabic: String?
    let english: String
    let attribution: String
    let onDone: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    @State private var rendered: Image?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            SheetHeader(title: "Share") {
                OutlinePillButton("Done", height: ReaderMetrics.sheetDoneHeight, action: onDone)
                    .frame(width: ReaderMetrics.sheetDoneWidth)
                    .accessibilityIdentifier("shareSheet.done")
            } trailing: {
                Color.clear.frame(width: ReaderMetrics.sheetDoneWidth, height: 1)
            }

            card
                .clipShape(.rect(cornerRadius: Radius.cardLarge, style: .continuous))
                .padding(.horizontal, Spacing.pageMargin)
                .accessibilityIdentifier("shareSheet.card")

            if let rendered {
                ShareLink(
                    item: rendered,
                    preview: SharePreview(reference, image: rendered)
                ) {
                    Text("Share")
                        .font(.geoSemibold(17))
                        .foregroundStyle(Color.textOnPill)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.pillHeight)
                        .background(Color.pillFill, in: .capsule)
                }
                .padding(.horizontal, Spacing.pageMargin)
                .accessibilityIdentifier("shareSheet.share")
            } else {
                ProgressView()
                    .accessibilityLabel("Preparing the share card")
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Spacing.xxl)
        .background(Color.sheetBackground)
        .task { rendered = render() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shareSheet")
    }

    private var card: ShareCard {
        ShareCard(reference: reference, arabic: arabic, english: english, attribution: attribution)
    }

    @MainActor
    private func render() -> Image? {
        // Rendered in the ambient scheme so the sheet's preview and the image the reader
        // actually shares are the same picture.
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, colorScheme))
        renderer.scale = displayScale
        #if canImport(UIKit)
            return renderer.uiImage.map(Image.init(uiImage:))
        #elseif canImport(AppKit)
            return renderer.nsImage.map(Image.init(nsImage:))
        #else
            return nil
        #endif
    }
}
