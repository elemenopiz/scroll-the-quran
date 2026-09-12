import CoreGraphics
@testable import FeatureReader
import Testing

/// Phase 4e grew the surah opening card on the owner's direction. The numbers still have to
/// hang together with the artwork (`CARD_SCALE` in `Artwork/tools/logo.sh`) and with the rest
/// of the page, which has to stay balanced once the card is 18 pt taller.
@Suite("Reader logo card metrics")
struct ReaderLogoCardMetricsTests {
    @Test("the card is 112 pt with the mark at 0.80 of it")
    func cardAndMarkSizes() {
        #expect(ReaderMetrics.logoCardSize == 112)
        #expect(abs(ReaderMetrics.logoMarkSize / ReaderMetrics.logoCardSize - 0.80) < 0.01)
    }

    /// The card hangs below the toolbar; the verse block below it is centred on 57.7 % of the
    /// page, so the card must still finish well above where the verse ink starts.
    @Test("the card still clears the verse block")
    func cardClearsTheVerseBlock() {
        let safeTop = ReaderMetrics.referenceTopInset
        let toolbarBottom = safeTop + ReaderMetrics.toolbarTopInset + ReaderMetrics.toolbarHeight
        let cardBottom = toolbarBottom + ReaderMetrics.logoCardTopFromToolbar + ReaderMetrics.logoCardSize
        let pageTop = safeTop
        let pageBottom = ReaderMetrics.referenceSize.height - ReaderMetrics.referenceBottomInset
        let verseCentre = pageTop + (pageBottom - pageTop) * ReaderMetrics.verseCentreFraction
        #expect(cardBottom < verseCentre - 100)
    }

    /// The mark is centred in the card, so the ring keeps an even margin all round.
    @Test("the mark keeps an even inset inside the card")
    func markInsetIsEven() {
        let inset = (ReaderMetrics.logoCardSize - ReaderMetrics.logoMarkSize) / 2
        #expect(inset > 0)
        #expect(inset >= ReaderMetrics.logoCardRadius / 2)
    }
}
