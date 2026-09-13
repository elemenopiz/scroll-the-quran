import DesignSystem
import SwiftUI

/// Plan id (or artwork slug) → the name of the cover image in the **app's** asset catalog.
///
/// **Duplication, deliberate and flagged.** The same table lives in
/// `AppShell/ArtworkAssets.swift` (`ArtworkAsset.planCoverBySlug`). `FeatureHome` cannot import
/// `AppShell` — `AppShell` depends on `FeatureHome`, not the other way round — and the catalog
/// itself is compiled into the app bundle, not into any package, so the names have to be spelled
/// somewhere on this side of the graph. When a cover is added or renamed, both tables move.
/// `Content/plans.json` now carries an `image` slug per plan, so the id fallback below is only
/// there for a plan written before that field existed.
enum PlanCoverArtwork {
    /// The catalog prefix every cover shares.
    static let prefix = "PlanCover-"

    /// Artwork slugs, in catalog order. Mirrors `ArtworkAsset.planCovers`.
    static let slugs = [
        "mushaf-page", "prayer-beads", "geometric-tile", "dawn-light",
        "lantern", "ink-wash", "desert-dune", "olive-branch",
        "night-window", "crescent-sky", "morning-doorway", "caravan-road",
        "wheat-and-well", "open-hands", "rain-on-stone", "writing-board",
        "stacked-volumes", "first-page",
    ]

    /// Plan id → slug, for plans whose JSON has no `image`. Mirrors `ArtworkAsset.planCoverBySlug`
    /// and the `image` field `Tools/content-gen/plans/catalogue.mjs` writes.
    static let slugByPlanID = [
        "first-week": "first-page",
        "juz-amma": "lantern",
        "protection-verses": "geometric-tile",
        "al-kahf-fridays": "ink-wash",
        "juz-a-day": "mushaf-page",
        "khatm-60": "stacked-volumes",
        "ramadan-khatm": "crescent-sky",
        "mulk-every-night": "night-window",
        "baqarah-nights": "geometric-tile",
        "three-quls-morning-evening": "morning-doorway",
        "prophets-in-the-quran": "caravan-road",
        "surah-yusuf": "wheat-and-well",
        "patience": "desert-dune",
        "gratitude": "olive-branch",
        "mercy": "dawn-light",
        "tawbah": "rain-on-stone",
        "duas-of-the-quran": "open-hands",
        "short-surahs-40": "writing-board",
    ]

    /// The scrim overlaid on a cover so white type reads over the artwork.
    static let scrimName = "PlanCoverScrim"

    /// The catalog name for a plan, or nil when neither its `image` slug nor its id is known.
    static func assetName(image: String?, planID: String) -> String? {
        if let image, !image.isEmpty {
            let slug = image.hasPrefix(prefix) ? String(image.dropFirst(prefix.count)) : image
            if slugs.contains(slug) {
                return prefix + slug
            }
        }
        if let slug = slugByPlanID[planID] {
            return prefix + slug
        }
        return nil
    }

    static func assetName(for plan: ReadingPlan) -> String? {
        assetName(image: plan.image, planID: plan.id)
    }
}

/// A plan cover, resolved from the app bundle's asset catalog.
///
/// The catalog is compiled into the app, so `Bundle.main` is the only bundle that has it:
/// SwiftUI previews and package tests render the fallback wash instead of the photograph.
///
/// **The crop is anchored on the subject, not the frame's centre.** All three places a cover
/// is drawn — the 173.5 pt plans-grid tile, Home's 125/133 pt squares and the 1.95:1
/// plan-detail hero — crop rather than letterbox, and the renders put their subject
/// off-centre by design (see `PlanCoverFocal.swift`). So the photograph is sized to fill,
/// slid onto its slug's anchor and clipped: the overflow is trimmed on the side *away* from
/// the subject. The scrim and the fallback stay full-frame — they are ramps, not pictures,
/// and have nothing to keep whole.
struct PlanCoverImage: View {
    let plan: ReadingPlan?
    var scrimmed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallback
                if let name = plan.flatMap(PlanCoverArtwork.assetName(for:)) {
                    focalImage(named: name, in: proxy.size)
                } else if plan == nil {
                    // No plan running: Home's "Pick a plan to begin" card had a featureless
                    // grey square where the cover goes, which reads as artwork that failed to
                    // load rather than as an empty state. The same closed book Deep Study's
                    // empty state uses, so the two agree.
                    Image(systemName: "book.closed")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.38, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                }
                if scrimmed {
                    Image(PlanCoverArtwork.scrimName, bundle: .main)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// The photograph scaled to fill `size`, then slid onto its focal anchor.
    ///
    /// The filled size is computed rather than left to `.scaledToFill()`, because the offset
    /// is derived from it and `scaledToFill` never reports it. `.offset` is a render-time
    /// shift — the layout box stays `size` — so the enclosing `.clipped()` still trims to the
    /// tile, and the shift is measured from the centred position because `.frame` centres a
    /// sized child before the offset is applied.
    private func focalImage(named name: String, in size: CGSize) -> some View {
        let filled = PlanCoverArtwork.filledSize(container: size)
        let shift = PlanCoverArtwork.centerOffset(
            container: size,
            scaled: filled,
            focal: PlanCoverArtwork.focal(for: plan)
        )
        return Image(name, bundle: .main)
            .resizable()
            .frame(width: filled.width, height: filled.height)
            .offset(x: shift.width, y: shift.height)
    }

    /// A deterministic two-stop wash keyed off the plan id, so a missing catalog still gives
    /// every plan its own colour instead of an empty rectangle.
    private var fallback: some View {
        LinearGradient(
            colors: [Color.chipBackground, Color.rowBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
