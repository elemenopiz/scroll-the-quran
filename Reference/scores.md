# RMSE scores against `Reference/`

How to read this: `Tools/snapshot/compare.sh <id>` normalises both images to 393x852 pt,
masks the status bar and home indicator, blurs both at sigma 6 and prints a normalised
RMSE. Thresholds live in `Tools/snapshot/thresholds.json`. A score is only meaningful
next to its diff PNG — `.build/snapshots/<id>-diff.png`.

## Brand (Phase 4e)

Three of these screens are deliberately **not** a pixel match any more. The owner's
direction was that the mark must sit unobstructed everywhere, read bigger on the icon and
inside the app, and that the wax seal should carry our own logo. Each of those moves us
away from the reference on purpose; the cost is recorded here so a later phase does not
"fix" it back.

| screen | before | after | threshold | note |
| --- | --- | --- | --- | --- |
| `gift-closed` | 0.0332 | **0.0292** | 0.10 | improved: warmer paper, the drop shadow now renders, the creases meet under the seal |
| `gift-open` | 0.0405 | **0.0346** | 0.10 | improved: OFF pill matches the reference, offer card starts at y 162 so the flap peak shows |
| `paywall-trial` | 0.0279 | **0.0346** | 0.06 | **accepted deviation** — see below |
| `reader-dark` | 0.0379 | **0.0414** | 0.05 | **accepted deviation** — see below |
| `reader-light` | 0.0620 | **0.0631** | 0.08 | **accepted deviation** — the same 112 pt card, negated capture |

### Accepted deviations

**Paywall header mark — +0.0067 RMSE.** The reference draws the mark 58x54 pt with its top
edge at y 47. On an iPhone 17 Pro the Dynamic Island's bottom edge is at 51.7 pt, so the
reference's own position puts the mark *behind* the island — the original was captured on a
device where that was not visible in the screenshot. Ours is 72 pt square with its top
anchored to the real safe-area top inset (`PaywallMetrics.logoTop(safeAreaTop:screen:)`,
mapped back through `ReferenceCanvas`'s scale), which lands it at 64 pt on this device:
13.9 pt of air below the island, and it still clears the status bar on notch and notchless
devices. The headline did not move; the extra height came out of the gap above it.

**Reader logo card — +0.0035 RMSE (dark), +0.0011 (light).** The reference card is 281 px
(93.7 pt) with a 70 pt mark. Ours is 112 pt with a 90 pt mark (0.80 of the card, matching
`CARD_SCALE` in `Artwork/tools/logo.sh`, so the shipped artwork is pixel-exact at every
scale). The surah page still balances: card, Bismillah, English line, surah name.

**Wax seal motif — no measurable cost.** Both gift screens strike the app's arabesque ring
into the wax instead of the reference's crown of thorns. The shape is different by
necessity; under the comparison blur it scores the same, but it is a deliberate difference
and should not be read as drift.

**App icon — not snapshot-compared.** Grey ground (`#3C3C41` centre, `#2F2F34` rim) with a
white mark at 86 % of the canvas, for both the default and the dark appearance; tinted
stays white on flat black. The three candidates the owner was shown are in
`Artwork/AppIcon/icon-candidates.png` and the shipped one under iOS's corner mask at 60 pt
is `Artwork/AppIcon/icon-masked-60.png`.

## Gift artwork (Phase 4f)

Both gift screens now draw the generated photoreal envelope instead of the vector art.
`Artwork/tools/gift-assets.sh` cuts every layer out of the renders in `Artwork/src/gift/`
and prints the geometry `PaywallMetrics.openEnvelopeArt` carries, so a re-rendered
envelope is one image plus six numbers.

| screen | before (4e, vector) | after (4f, render) | threshold | note |
| --- | --- | --- | --- | --- |
| `gift-closed` | 0.0292 | **0.0424** | 0.10 | **accepted deviation** — see below |
| `gift-open` | 0.0346 | **0.0625** | 0.10 | **accepted deviation** — see below |

Both went *up*. That is the price of photorealism against a flat reference, and it is
paid deliberately: the screens are judged on the reference's proportions and reading
order, which they keep, not on matching an illustration pixel for pixel.

### Accepted deviations

**The sky — most of the residue on both screens.** `GiftClouds` is a real cumulus render.
It is toned to `gift-closed.png`'s own sky band per channel (mean 227.8 / 221.6 / 203.8,
sd 7.4 / 9.0 / 13.7 — measured from the reference, applied in `tone_sky`), so it sits at
the right brightness and the right flatness; but its clouds are where the render put them
and the reference's are where the reference put them, and no toning fixes that. The
reference's sky is also mostly empty warm paper with two or three soft banks, where a real
sky has weather everywhere.

**The paper.** The renders came back a browner kraft than the reference's lit cream, so
`tone_paper` lifts the paper onto the reference's own samples (231.7 / 213.1 / 179.1
closed, 242.9 / 219.6 / 181.2 open) and leaves the wax alone — the render's gold already
matches the reference's seal to within three levels on red and green. What is left is
modelling: the render lights its faces (bright front pocket, shaded flap lining) where the
reference's envelope is nearly one flat tone. Flattening that out would throw away the
only thing the render is here for.

**`gift-open`'s pocket is shallower than the reference's.** The render's front pocket is
0.60 of the envelope's width deep; the reference's is 0.71. Anchoring the envelope's
bottom edge to the reference's y 579 therefore puts the pocket's top corners at y 379
where the reference's are at 338. The card is clipped at that mouth — flat across the
corners, dipping to the point under the seal (`PocketMouth`, and
`OpenEnvelope.pocketEdgeY(atX:)`) — which is what keeps all five rows of the offer copy
readable; `GiftArtworkGeometryTests` asserts that every row clears it at the card's edges.

**The closed envelope is ~8 pt taller than the reference's.** The render is 1.46 : 1 where
the reference's envelope is 1.54 : 1. Width is what the eye measures on a 235 pt element,
so width is matched and the extra height is accepted.

**The seal.** Both screens show the *same* seal: the closed envelope's is baked into its
render, and `WaxSealLogo` is that identical seal traced off the paper it was pressed on
(`trace_seal`). It carries the app's arabesque ring, not the reference's crown of thorns —
Phase 4e's decision, unchanged.

**The reveal animation** was checked frame by frame (`.build/snapshots/gift-reveal-mid.png`):
the open state cross-fades in with every element already in its final place, so there is no
layout jump between the two states.
