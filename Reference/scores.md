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
