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
struct PlanCoverImage: View {
    let plan: ReadingPlan?
    var scrimmed = false

    var body: some View {
        ZStack {
            fallback
            if let name = plan.flatMap(PlanCoverArtwork.assetName(for:)) {
                Image(name, bundle: .main)
                    .resizable()
                    .scaledToFill()
            } else if plan == nil {
                // No plan running: Home's "Pick a plan to begin" card had a featureless
                // grey square where the cover goes, which reads as artwork that failed to
                // load rather than as an empty state. The same closed book Deep Study's
                // empty state uses, so the two agree.
                GeometryReader { proxy in
                    Image(systemName: "book.closed")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.38, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            if scrimmed {
                Image(PlanCoverArtwork.scrimName, bundle: .main)
                    .resizable()
                    .scaledToFill()
            }
        }
        .accessibilityHidden(true)
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
