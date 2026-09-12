import SwiftUI

/// Every raster shipped in `App/Assets.xcassets` (see `Artwork/README.md` for how each
/// one was generated and how it is meant to be composited).
///
/// The catalog is compiled into the **app** bundle, so these resolve through
/// `Bundle.main`; SwiftUI previews inside the package will show a placeholder.
///
/// Compositing notes carried over from the artwork brief:
/// - `planCoverScrim` / `charityCardScrim` are meant to be `.overlay`ed (normal blend)
///   over a cover or charity image so white titles read.
/// - The opened envelope (Phase 4f) is a stack: `giftClouds` → `envelopeOpen` →
///   `envelopeCard` clipped at the pocket mouth → `waxSealLogo`; the geometry comes
///   from `PaywallMetrics.openEnvelope(...)`, derived from the layer's own canvas.
/// - `phoneFrame`'s screen window is `x 30, y 30, 1119 × 2496` in the 1179×2556
///   artwork space. It is 0.4484:1 while a real screenshot is 0.4613:1, so scale the
///   screenshot to *fill* the window and clip it to `RoundedRectangle(cornerRadius: 160)`
///   (a ~1.5 % vertical crop). Never stretch it.
public enum ArtworkAsset: String, CaseIterable, Sendable {
    // MARK: - Logo

    /// White line-art mark on transparency, 64 pt (@1x/@2x/@3x).
    case logoMarkWhite = "LogoMarkWhite"
    /// Black line-art mark on transparency, 64 pt (@1x/@2x/@3x).
    case logoMarkBlack = "LogoMarkBlack"
    /// The reader's centred logo card, dark ground, 96 pt (@1x/@2x/@3x).
    case logoCard = "LogoCard"
    /// Light-appearance logo card, 96 pt (@1x/@2x/@3x).
    case logoCardLight = "LogoCardLight"

    // MARK: - Gift flow

    /// Warm beige cloud sky behind the gift screens (1179×2556).
    case giftClouds = "GiftClouds"
    /// Closed envelope with the logo wax seal baked in (1200×900, transparent).
    case envelopeClosed = "EnvelopeClosed"
    /// Opened, empty envelope with the tall raised flap (1000×1500, transparent).
    case envelopeOpen = "EnvelopeOpen"
    /// The blank cream card that stands in the pocket (900×1200, transparent).
    case envelopeCard = "EnvelopeCard"
    /// The logo wax seal cut from the render, for the open envelope (600×600, transparent).
    case waxSealLogo = "WaxSealLogo"
    /// A blank gold seal for a code-embossed fallback (600×600, transparent).
    case waxSealBlank = "WaxSealBlank"

    // MARK: - Onboarding

    /// Transparent iPhone frame to overlay our own screenshots (1179×2556).
    case phoneFrame = "PhoneFrame"

    // MARK: - Scrims

    /// Reusable dark overlay for reading-plan covers (1200×800).
    case planCoverScrim = "PlanCoverScrim"
    /// Reusable dark overlay for charity cards (1200×600).
    case charityCardScrim = "CharityCardScrim"

    // MARK: - Reading-plan covers (1200×800 JPEG, no text baked in)

    case planCoverMushafPage = "PlanCover-mushaf-page"
    case planCoverPrayerBeads = "PlanCover-prayer-beads"
    case planCoverGeometricTile = "PlanCover-geometric-tile"
    case planCoverDawnLight = "PlanCover-dawn-light"
    case planCoverLantern = "PlanCover-lantern"
    case planCoverInkWash = "PlanCover-ink-wash"
    case planCoverDesertDune = "PlanCover-desert-dune"
    case planCoverOliveBranch = "PlanCover-olive-branch"
    case planCoverNightWindow = "PlanCover-night-window"
    case planCoverCrescentSky = "PlanCover-crescent-sky"
    case planCoverMorningDoorway = "PlanCover-morning-doorway"
    case planCoverCaravanRoad = "PlanCover-caravan-road"
    case planCoverWheatAndWell = "PlanCover-wheat-and-well"
    case planCoverOpenHands = "PlanCover-open-hands"
    case planCoverRainOnStone = "PlanCover-rain-on-stone"
    case planCoverWritingBoard = "PlanCover-writing-board"
    case planCoverStackedVolumes = "PlanCover-stacked-volumes"
    case planCoverFirstPage = "PlanCover-first-page"

    // MARK: - Charity card imagery (1200×600 JPEG, no real organisations, no faces)

    case charityGivingHands = "Charity-giving-hands"
    case charityHarvestWheat = "Charity-harvest-wheat"
    case charityCleanWater = "Charity-clean-water"

    /// The catalog name, identical to the raw value.
    public var name: String {
        rawValue
    }

    /// The image, resolved from the app bundle's asset catalog.
    public var image: Image {
        Image(rawValue)
    }
}

// MARK: - Content slug mapping

public extension ArtworkAsset {
    /// Every reading-plan cover, in catalog order.
    static let planCovers: [ArtworkAsset] = [
        .planCoverMushafPage, .planCoverPrayerBeads, .planCoverGeometricTile,
        .planCoverDawnLight, .planCoverLantern, .planCoverInkWash,
        .planCoverDesertDune, .planCoverOliveBranch, .planCoverNightWindow,
        .planCoverCrescentSky, .planCoverMorningDoorway, .planCoverCaravanRoad,
        .planCoverWheatAndWell, .planCoverOpenHands, .planCoverRainOnStone,
        .planCoverWritingBoard, .planCoverStackedVolumes, .planCoverFirstPage,
    ]

    /// Every charity card image, in catalog order.
    static let charityImages: [ArtworkAsset] = [
        .charityGivingHands, .charityHarvestWheat, .charityCleanWater,
    ]

    /// Plan id (`Content/plans.json` → `plans[].id`) → cover artwork.
    ///
    /// `plans.json` carries an `image` slug per plan, so the artwork slugs
    /// (`mushaf-page`, `lantern`, …) are the live path; the plan ids below are the
    /// fallback for a plan written before that field existed. Both tables mirror
    /// `Tools/content-gen/plans/catalogue.mjs`.
    static let planCoverBySlug: [String: ArtworkAsset] = {
        var map: [String: ArtworkAsset] = [
            // Content/plans.json ids
            "first-week": .planCoverFirstPage,
            "juz-amma": .planCoverLantern,
            "protection-verses": .planCoverGeometricTile,
            "al-kahf-fridays": .planCoverInkWash,
            "juz-a-day": .planCoverMushafPage,
            "khatm-60": .planCoverStackedVolumes,
            "ramadan-khatm": .planCoverCrescentSky,
            "mulk-every-night": .planCoverNightWindow,
            "baqarah-nights": .planCoverGeometricTile,
            "three-quls-morning-evening": .planCoverMorningDoorway,
            "prophets-in-the-quran": .planCoverCaravanRoad,
            "surah-yusuf": .planCoverWheatAndWell,
            "patience": .planCoverDesertDune,
            "gratitude": .planCoverOliveBranch,
            "mercy": .planCoverDawnLight,
            "tawbah": .planCoverRainOnStone,
            "duas-of-the-quran": .planCoverOpenHands,
            "short-surahs-40": .planCoverWritingBoard,
        ]
        // Artwork slugs, e.g. "prayer-beads" -> .planCoverPrayerBeads
        for cover in planCovers {
            map[String(cover.rawValue.dropFirst("PlanCover-".count))] = cover
        }
        return map
    }()

    /// Charity id (`Content/charities.json` → `organisations[].id`) → card artwork.
    ///
    /// `charities.json` carries no image field either, so the organisation id is the
    /// slug. The artwork slugs (`giving-hands`, …) are accepted as well.
    static let charityImageBySlug: [String: ArtworkAsset] = {
        var map: [String: ArtworkAsset] = [
            // Content/charities.json ids
            "islamic-relief": .charityGivingHands,
            "penny-appeal": .charityCleanWater,
            "human-appeal": .charityHarvestWheat,
        ]
        for card in charityImages {
            map[String(card.rawValue.dropFirst("Charity-".count))] = card
        }
        return map
    }()

    /// The cover for a reading plan, by plan id or artwork slug. `nil` when unknown.
    static func planCover(_ slug: String) -> Image? {
        planCoverBySlug[slug]?.image
    }

    /// The card image for a charity, by organisation id or artwork slug. `nil` when unknown.
    static func charityImage(_ slug: String) -> Image? {
        charityImageBySlug[slug]?.image
    }
}
