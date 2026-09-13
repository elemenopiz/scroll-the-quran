import CoreGraphics
import SwiftUI

// Where each plan cover's subject sits inside its frame, and the crop maths that keeps
// that subject whole when a 3:2 photograph is filled into a square tile or a wide hero.
//
// The 18 renders in `Artwork/src/covers/` were made to `docs/design/asset-prompts.md`,
// which deliberately put every subject **off-centre** — usually in the lower-left or
// lower-right third — so a title could sit over a calm top. A centre crop therefore
// slices exactly the thing the cover is of: the lantern loses its left half, the mushaf
// hangs off the right edge, the crescent drifts to the frame's corner. The table below
// names, per slug, the anchor that trims the *empty* side instead.

extension PlanCoverArtwork {
    /// A crop anchor in the source frame's own unit space, read like `UnitPoint`:
    /// `0` keeps the leading/top edge, `1` keeps the trailing/bottom edge, `0.5` centres.
    ///
    /// The covers are 3:2, so only one axis is ever cropped: a **square** tile trims the
    /// width (and `y` is inert), the **1.95:1 hero** trims the height (and `x` is inert).
    /// Both components are stored anyway so one table serves every future aspect.
    struct Focal: Equatable, Sendable {
        var x: CGFloat
        var y: CGFloat

        init(_ x: CGFloat, _ y: CGFloat) {
            self.x = x
            self.y = y
        }

        /// The crop anchor for an unknown slug: dead centre, which is what the app did
        /// everywhere before this table existed.
        static let center = Focal(0.5, 0.5)

        var unitPoint: UnitPoint {
            UnitPoint(x: x, y: y)
        }
    }

    /// The aspect (width ÷ height) every shipped cover is cut to — `1200 × 800`.
    /// `Artwork/tools/covers-from-src.sh` resamples the 1536×1024 renders to it without
    /// cropping, so the shipped JPEG and the source PNG frame the same picture.
    static let sourceAspect: CGFloat = 1.5

    /// Slug → crop anchor. One line per cover saying where its subject actually is.
    ///
    /// A square tile can only slide its window across the middle third of the frame, so an
    /// anchor of `0` or `1` means "as far as the crop can go" rather than "flush with the
    /// edge of the subject"; the hero's window has even less room (23 % of the height).
    static let focal: [String: Focal] = [
        // mushaf on a rehal, lower right third; the left half is bare wall.
        "mushaf-page": Focal(1.0, 1.0),
        // tasbih and its tassel run from the left edge to mid-frame; the right is empty linen.
        "prayer-beads": Focal(0.0, 1.0),
        // a pattern, not an object: the sharpest star tiles are lower centre-right.
        "geometric-tile": Focal(0.62, 0.95),
        // minaret and the sunrise glow are both on the right; the left is haze.
        "dawn-light": Focal(1.0, 0.9),
        // lantern hard against the left edge, mid height — the centre crop halved it.
        "lantern": Focal(0.05, 0.5),
        // reed pen runs in from the left; its nib and the inkpot sit right of centre.
        "ink-wash": Focal(1.0, 1.0),
        // one crest, peaking at x ≈ 0.38; anchoring left of centre puts it on the third.
        "desert-dune": Focal(0.35, 1.0),
        // the sprig enters from the right edge and its olives sit at x ≈ 0.8.
        "olive-branch": Focal(1.0, 0.95),
        // oil lamp and closed book in the leftmost quarter of a dark sill.
        "night-window": Focal(0.02, 1.0),
        // crescent upper right, dome lower right: the hero needs both, so it stays centred.
        "crescent-sky": Focal(1.0, 0.5),
        // the open door and the sunlit courtyard beyond are the right third.
        "morning-doorway": Focal(1.0, 0.55),
        // the track enters bottom-centre and winds up the left half.
        "caravan-road": Focal(0.15, 0.55),
        // sheaves lean on the well; both are right of centre, the left is empty plain.
        "wheat-and-well": Focal(1.0, 1.0),
        // two palms, lower left, against otherwise empty cloth.
        "open-hands": Focal(0.0, 1.0),
        // the wet, droplet-bearing stone and the crack are the lower right.
        "rain-on-stone": Focal(1.0, 1.0),
        // writing board and pot occupy the left half; the right is blank plaster.
        "writing-board": Focal(0.0, 1.0),
        // the row of spines spans x 0.35–0.93, so the window rides near the right.
        "stacked-volumes": Focal(0.92, 1.0),
        // open mushaf lower right; the lantern and doorway are soft background.
        "first-page": Focal(1.0, 1.0),
    ]

    /// The anchor for an artwork slug, with or without the catalog prefix.
    static func focal(slug: String) -> Focal {
        let bare = slug.hasPrefix(prefix) ? String(slug.dropFirst(prefix.count)) : slug
        return focal[bare] ?? .center
    }

    /// The anchor for a plan, resolved through the same `image`-then-id path as its asset.
    static func focal(for plan: ReadingPlan?) -> Focal {
        guard let plan, let name = assetName(for: plan) else { return .center }
        return focal(slug: name)
    }

    // MARK: Crop maths

    /// The size a `sourceAspect` image takes when scaled to *fill* `container` — the
    /// larger of the two scale factors, so one axis matches and the other overflows.
    static func filledSize(container: CGSize, sourceAspect: CGFloat = PlanCoverArtwork.sourceAspect) -> CGSize {
        guard container.width > 0, container.height > 0, sourceAspect > 0 else { return .zero }
        if container.width / container.height >= sourceAspect {
            return CGSize(width: container.width, height: container.width / sourceAspect)
        }
        return CGSize(width: container.height * sourceAspect, height: container.height)
    }

    /// Where the filled image's top-left corner lands: `(container − scaled) × anchor`.
    ///
    /// `container − scaled` is zero or negative on each axis, so anchor `0` pins the
    /// image's leading/top edge to the container's and anchor `1` pins its trailing/bottom
    /// edge — the overflow is always trimmed on the side *away* from the subject.
    static func origin(container: CGSize, scaled: CGSize, focal: Focal) -> CGPoint {
        CGPoint(
            x: (container.width - scaled.width) * focal.x,
            y: (container.height - scaled.height) * focal.y
        )
    }

    /// The same placement expressed as a shift from the centred position, which is what
    /// SwiftUI's `.frame(_:_:) + .offset(_:)` pair actually needs: a sized child is
    /// centred in its parent frame first, so only the delta from centre is applied.
    static func centerOffset(container: CGSize, scaled: CGSize, focal: Focal) -> CGSize {
        let placed = origin(container: container, scaled: scaled, focal: focal)
        return CGSize(
            width: placed.x - (container.width - scaled.width) / 2,
            height: placed.y - (container.height - scaled.height) / 2
        )
    }

    /// The slice of the source frame a crop actually shows, in the source's unit space —
    /// the thing the contact sheet in `docs/design/cover-crops-contact.jpg` draws.
    static func visibleRect(container: CGSize, scaled: CGSize, focal: Focal) -> CGRect {
        guard scaled.width > 0, scaled.height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let w = min(1, container.width / scaled.width)
        let h = min(1, container.height / scaled.height)
        return CGRect(x: (1 - w) * focal.x, y: (1 - h) * focal.y, width: w, height: h)
    }
}
