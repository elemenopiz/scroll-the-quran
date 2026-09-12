# Brand review walk — Phase 4e

Every `--screenshot` route in `Reference/manifest.json`, launched on **ScrollSim-3d**
(iPhone 17 Pro, 402x874 pt, top safe-area inset **62 pt**, Dynamic Island bottom edge
measured at **51 pt**) in **both** appearances (`xcrun simctl ui <udid> appearance
dark|light`). Captures are in `.build/snapshots/brand-review/<id>-{dark,light}.png`;
six-up contact sheets alongside them as `sheet-{dark,light}-{1..4}.png`.

Everything in the **Fixed** column was inside Phase 4e's owned paths and is fixed on
`phase4/4e-brand`. Everything under **Out of scope** is listed with a file path for
whoever owns it.

## Where the mark appears

| surface | mark | size | clearance | verdict |
| --- | --- | --- | --- | --- |
| app icon (default + dark) | yes | 86 % of the canvas | diagonal finials sit ~190 px inside iOS's corner mask on the 1024; `Artwork/AppIcon/icon-masked-60.png` is the 60 pt check | good |
| app icon (tinted) | yes | 86 %, mono white on flat black | same | good |
| `paywall-trial` | yes | 72 pt square | ink starts at y 65 pt, **14 pt below the island** | good, both appearances |
| `paywall-plans` | yes (same header, behind the sheet) | 72 pt | same | good, both appearances |
| `gift-closed` | yes — struck into the wax seal | 46.5 pt inside a 75 pt seal | n/a | good, both appearances |
| `gift-open` | yes — struck into the wax seal | 57 pt inside a 92 pt seal | n/a | good, both appearances |
| `reader` (surah page 0) | yes — the logo card | 112 pt card, 90 pt mark | 28 pt below the toolbar, 100+ pt above the verse block | good, both appearances |
| onboarding (7 routes) | no | — | — | matches the reference: the hook and the slides carry no mark |
| `community`, `discover`, `deepstudy` (4), `home` (2), `translation-sheet`, `notes-sheet` | no | — | — | matches the reference |
| lock/home-screen widget | no | — | — | the widget target has no asset catalog, and `project.yml` is frozen — noted, not a regression |

## Fixed in this task

1. **`paywall-trial` / `paywall-plans` — the mark was behind the Dynamic Island.** The
   reference's y = 47 with a 58x54 box put the ring under the island on every island
   device. Now 72 pt square, anchored to the real safe-area top inset and mapped back
   through `ReferenceCanvas`'s scale. 14 pt of air, both appearances.
   (`FeaturePaywall/PaywallMetrics.swift`, `PaywallTrialView.swift`)
2. **`gift-open` — the OFF pill covered the "33%".** 72x47 at y 255, straight across the
   digits. Now 69x33 at y 270 with a 3.3 pt white outline, tucked under the baseline.
   (`FeaturePaywall/PaywallMetrics.swift`, `GiftOfferView.swift`)
3. **`gift-open` — the offer card swallowed the envelope's flap peak.** The card started
   at y 143 where the reference starts at 162, leaving a sliver instead of a triangle.
   (`FeaturePaywall/PaywallMetrics.swift`)
4. **`gift-closed` — the envelope's drop shadow never rendered.** `.shadow()` was applied
   inside the `.clipShape()` that trimmed the paper, so it was clipped away with
   everything else. Clip, then shadow, with the seal hung off an overlay.
   (`FeaturePaywall/EnvelopeArt.swift`)
5. **`gift-closed` — the creases did not meet under the seal.** The flap's point was at
   0.62 of the height and the bottom fold's at 0.52, so the junction emerged past the
   wax. All four creases now meet at 0.52, where the seal is centred.
   (`FeaturePaywall/EnvelopeArt.swift`)
6. **`gift-closed` — the paper read near-white.** The gradient ramped from `cloudWarm`
   (`#F8F4EC`); the reference samples `#F4E4C9` down to `#EADBBE`. New
   `GiftPalette.envelopePaper` (`#F6E9D2`). (`FeaturePaywall/GiftPalette.swift`)
7. **`gift-open` / `gift-closed` — the pills inverted in dark appearance.** The gift
   screens are a fixed warm-paper composition, but the price pill and the call to action
   used `Color.pillFill` and the "+3 day trial" pill used `Color.appBackgroundFlat`. Under
   a dark system setting the first two turned white-on-cream and the trial pill went
   black-on-black — illegible. All three are pinned to `GiftPalette` now, and `PillButton`
   takes an optional fill/label pair so the paywall keeps following the appearance.
   (`FeaturePaywall/GiftPalette.swift`, `GiftOfferView.swift`, `PaywallTrialView.swift`)
8. **The wax seal carried a second mark.** It was struck with a crescent-and-star that
   appears nowhere else in the app. It now carries the brand ring, embossed.
   (`FeaturePaywall/EnvelopeArt.swift`, `DesignSystem/Components/BrandMark.swift`;
   `CrescentStarMark.swift` deleted)

## Out of scope — for Phase 4b / 4d

Each of these was seen in this walk and is **not** in Phase 4e's owned paths.

1. **Deep Study scrolls under the status bar, unmasked.** `deepstudy-top`, `-mid`,
   `-crossrefs` and `-bottom` all show body text and section headers colliding with the
   clock, Wi-Fi and battery glyphs at the top of the sheet — no scrim, no blur, no inset.
   Worst on `deepstudy-mid`/`-crossrefs`, where a whole line of the quote box runs behind
   the status bar. Both appearances.
   → `Packages/ScrollKit/Sources/FeatureDiscover/` (the Deep Study sheet's scroll
   container and its top inset).
2. **Home scrolls under the status bar, unmasked.** Same defect on `home#scrolled`: the
   "Pick a plan to begin" card runs behind the clock. Both appearances.
   → `Packages/ScrollKit/Sources/FeatureHome/`.
3. **`onboarding-reviews` — the "Continue" pill sits on top of the third review card**
   with no scrim or fade behind it, so the card's text reads through the button's edges.
   Both appearances.
   → `Packages/ScrollKit/Sources/FeatureOnboarding/` (the reviews screen's footer).
4. **`onboarding-signin` in light appearance — the "Sign in with Apple" button is drawn
   with stray rules.** A hairline runs out of both sides of the capsule to the sheet's
   edges, and there are stray vertical ticks at the button's left and right. In dark
   appearance the same button is a clean white pill, so it is a light-token or
   divider-layering problem, not a layout one.
   → `Packages/ScrollKit/Sources/FeatureOnboarding/`.
5. **`onboarding-slide1..4` still show wireframe placeholder art** inside the phone
   frames — grey and black bars standing in for the reader, the plans list, Discover and
   search. The reference slides show real product screenshots. Also, slide 4's frame
   draws a round camera dot where slides 1–3 draw a Dynamic Island pill, so the four
   frames are not consistent with each other.
   → `Packages/ScrollKit/Sources/FeatureOnboarding/` (+ `Artwork/Frames/`, which is
   consistent; the dot is the mockup, not the frame).
6. **`home` — the "Today's Reading" cover renders as a blank grey rounded rectangle,**
   with no plan-cover artwork behind the title, and a pale panel bleeds behind the
   Community/Discover tab items. Both appearances.
   → `Packages/ScrollKit/Sources/FeatureHome/`.
7. **`notes-sheet` captures without the keyboard** (and in light appearance with the
   keyboard's "slide to type" onboarding overlay instead). The reference shows the
   keyboard up. This is the screenshot route not focusing the editor, not a layout fault.
   → `Packages/ScrollKit/Sources/FeatureReader/` route wiring, or the fixture.

8. **`OnboardingMetricsTests` is order-dependent and fails intermittently.** The suite's
   "Source Serif 4 already sets wider than the reference pitch" case reads
   `OnboardingMetrics.hookHeadlineExtraLineSpacing`, which measures Source Serif 4 through
   CoreText — so it only passes if something else in the same `swift test` process has
   already called `DesignSystem.registerFonts()`. Run on its own
   (`swift test --filter OnboardingMetricsTests`) it fails every time; in a full run it
   fails whenever the scheduler puts it first. Adding Phase 4e's 11 tests was enough to
   flip it once. The fix is for the suite to register the fonts itself rather than to rely
   on another suite having done it.
   → `Packages/ScrollKit/Tests/FeatureOnboardingTests/OnboardingMetricsTests.swift`.

## Tooling note

`Tools/snapshot/capture.sh` defaults to a 2 s settle (`SCROLL_CAPTURE_SETTLE`). On this
simulator that is **not enough on a cold launch** — the first capture of a run comes back
blank or half-laid-out, which reads as a screen regression when it is not. Every number in
this task was taken with `SCROLL_CAPTURE_SETTLE=5`, and the onboarding sheet needed 8. Worth
raising the default, or waiting on first paint instead of sleeping.
