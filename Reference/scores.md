# RMSE scores against `Reference/`

How to read this: `Tools/snapshot/compare.sh <id>` normalises both images to 393x852 pt,
masks the status bar and home indicator, blurs both at sigma 6 and prints a normalised
RMSE. Thresholds live in `Tools/snapshot/thresholds.json`. A score is only meaningful
next to its diff PNG — `.build/snapshots/<id>-diff.png`.

Reproduce the whole table with:

```bash
SCROLL_SIM=<udid> SCROLL_CAPTURE_SETTLE=6 Tools/verify.sh --snap all --both
```

`--snap all` is every id in this file's order; `--both` adds an unscored capture of each
screen in the other appearance, for the eye rather than the gate. Every capture launches
the app with `--reset-state`, so a score does not depend on what the last run left in the
App Group container (it used to: `plan-detail` scored 0.179 on a dirty container and 0.138
on a clean one from the identical build).

## Full sweep — Phase 4b, 2026-09-12

iPhone 17 Pro (`ScrollSim-3e`, iOS 26), `SCROLL_FIXED_DATE=2026-09-14`. 27 screens, all
under threshold. Three carry a raised threshold and an accepted-deviation note; the reasons
are below the table and repeated in `thresholds.json`.

| id | appearance | RMSE | threshold | verdict | notes |
| --- | --- | ---: | ---: | --- | --- |
| `onboarding-hook` | light | 0.0485 | 0.08 | pass | — |
| `onboarding-signin` | light | 0.0787 | 0.08 | pass | Apple button rebuilt: `.white` pill + our own capsule hairline, so the outline style's stray rules are gone. Was 0.0775 with the broken border. |
| `onboarding-slide1` | light | 0.0952 | 0.12 | pass | real reader capture in the phone frame (was wireframe art) |
| `onboarding-slide2` | light | 0.1245 | 0.13 | **accepted deviation** | plan cover artwork — see below |
| `onboarding-slide3` | light | 0.0567 | 0.12 | pass | real Discover capture in the phone frame (was wireframe art) |
| `onboarding-slide4` | light | 0.0705 | 0.12 | pass | real Verse Search capture |
| `onboarding-reviews` | light | 0.0739 | 0.10 | pass | Continue pill now has a fade behind it; placeholder author handle no longer drawn |
| `paywall-trial` | light | 0.0346 | 0.06 | pass | Phase 4e accepted deviation (72 pt mark clear of the island) — unchanged |
| `paywall-plans` | light | 0.0340 | 0.08 | pass | — |
| `gift-closed` | light | 0.0293 | 0.10 | pass | unchanged from Phase 4e |
| `gift-open` | light | 0.0346 | 0.10 | pass | unchanged from Phase 4e |
| `community-dark` | dark | 0.0539 | 0.10 | pass | opaque tab bar; charity card gained the light hairline (no dark change) |
| `discover-dark` | dark | 0.0591 | 0.14 | pass | opaque tab bar |
| `deepstudy-top` | dark | 0.0664 | 0.14 | pass | status-bar scrim |
| `deepstudy-mid` | dark | 0.0571 | 0.14 | pass | status-bar scrim — this is the screen where a whole line of the quote box ran behind the clock |
| `deepstudy-crossrefs` | dark | 0.0561 | 0.14 | pass | status-bar scrim |
| `deepstudy-bottom` | dark | 0.0491 | 0.14 | pass | status-bar scrim |
| `reader-dark` | dark | 0.0389 | 0.05 | pass | Phase 4e's 112 pt logo card kept; 0.0414 -> 0.0389 from the outline tab symbols |
| `reader-light` | light | 0.0642 | 0.08 | pass | negated capture; same accepted 112 pt card |
| `translation-sheet` | dark | 0.0411 | 0.10 | pass | — |
| `notes-sheet` | dark | 0.0236 | 0.12 | pass | keyboard is up in the capture — the 2 s settle was what lost it, not the route |
| `home-dark` | dark | 0.0638 | 0.10 | pass | status-bar scrim, opaque tab bar |
| `home-light` | light | 0.1021 | 0.16 | pass | reference is the slide-4 mockup's window, which shows a plan running where a reset install shows the empty state |
| `verse-search` | light | 0.1077 | 0.16 | pass | same reference window as `home-light` |
| `plans-sheet` | light | 0.1927 | 0.20 | **accepted deviation** | plan cover artwork — see below |
| `plan-detail` | light | 0.1382 | 0.145 | **accepted deviation** | plan cover artwork — see below |
| `tabbar-dark` | dark | 0.0375 | 0.12 | pass | 0.1128 -> 0.0375: outline symbols for unselected tabs, and the bar is opaque |

Every one of the 27 was also captured in the opposite appearance
(`.build/snapshots/<id>-<light|dark>.png`) and walked by eye. None of those are scored —
there is no reference for a screen in the appearance it was not designed in.

### Accepted deviations — Phase 4b

**Plan cover artwork — `plans-sheet` 0.1927, `plan-detail` 0.1382, `onboarding-slide2`
0.1245.** One root cause for all three. The reference app is Scroll the Bible and its plan
covers are licensed stock photographs — a magnifying glass on a book, a cross on cream, a
watch on blue. Ours are the generated covers in `App/Assets.xcassets`, which is frozen
after Phase 1 and outside this task's ownership, so the tone blocks cannot be brought
closer without editing a frozen path. Under the sigma-6 blur those blocks are most of what
the score sees:

- `plans-sheet`: header, search field, active-plan card, "FOR NEW READERS" section header
  and the 2-up cover grid all land on the reference; the grid and iOS dimming the parent
  black behind the sheet (the reference shows it grey) are the whole residue. Phase 3c
  measured 0.193 with the layout already matched.
- `plan-detail`: Close button, hero cover, title, meta line, call to action, about box and
  the detail rows land on the reference. The hero is a quarter of the frame and reads 191
  mean luminance against the reference's 143. Phase 3c measured 0.138.
- `onboarding-slide2`: the slide's own headline, subheadline, phone frame and call to
  action land on the reference; the residue is entirely inside the phone window, which is
  the plans screen above.

Thresholds were raised to 0.20 / 0.145 / 0.13 — measured value plus a little headroom — so
the gate still catches a regression on these screens without failing on a difference that
is deliberate. Do not "fix" them by darkening our covers to chase the number.

**Slide 2's phone frame no longer shows the sheet's dimmed band.** The `plans-sheet` route
is a sheet, so its capture carried 185 px of dimmed parent screen above the sheet's rounded
top edge, which read as a black bar inside a 228 pt frame. `render-mockups.sh` trims it and
pads the trim back with the sheet's own ground so the "Reading Plans / Done" header clears
the Dynamic Island that `PhoneFrame` draws. That moved the score 0.1255 -> 0.1245: it is a
presentation fix, not a score fix, and it is recorded here so it is not undone as useless.

### Professional-polish walk — Phase 4b

Both appearances, every screen. What was found and what was done:

| item | outcome |
| --- | --- |
| Clearance | Deep Study and Home scrolled under the status bar unmasked in both appearances (brand review 1, 2). Fixed with `StatusBarScrim`, sized off the real safe-area inset. Sheets keep their grabber; the reader's hint toast clears the tab bar. |
| Alignment and rhythm | Card paddings and page margins already come from `Spacing.*` and `HomeMetrics`/`DeepStudyMetrics`; no drift found across Discover, Home and Deep Study. |
| Typography hierarchy | No screen exceeded three text sizes. The muted Arabic line has a 13 pt floor and caps at 3 lines (branch commit `70aaf51`). |
| Radii and borders | Four surfaces set `Color.cardBackground` directly and had no edge on `#FAFAFC` — the Community charity card, `PlanCard` and both review cards. All now draw `CardContainer`'s `.cardEdge(radius:)`, a no-op in dark, so no measured dark value changed. |
| Iconography | Unselected tab icons were filled. `.environment(\.symbolVariants, .none)` on the `TabView` does nothing on iOS 26; moved onto each `Label` inside `tabItem`. Discover keeps `sparkles` in both states — there is no `sparkles.fill`, and `Image(systemName:)` draws nothing for a name that does not exist. |
| States | Home's "Pick a plan to begin" cover was a featureless grey square; it now carries the same closed book Deep Study's empty state uses. |
| Copy | `onboarding-reviews` printed the literal string "Placeholder review" as each card's author. The handle is omitted for a card flagged `placeholder` rather than replaced with an invented name. No other placeholder, lorem or TODO string reaches a screen. |
| Motion | No layout jump when the Arabic line loads; sheet and toast animations unchanged. The funnel's two call-to-action pills were on `.buttonStyle(.plain)` — the only pills in the app with no press feedback — and now use `.pressable` like the rest. |
| Dynamic Type at XL | Walked `reader`, `discover`, `deepstudy` (top and bottom) and `home` at `extra-large`. No clipped or overlapping text. The Discover card's meaning and "Did you know?" previews truncate with an ellipsis, which is their line limit doing its job. |
| Brand | Phase 4e's mark sizes and clearances were not touched. The mark reads correctly on `paywall-trial`, `paywall-plans`, both gift screens and the reader's logo card in both appearances. |
| Tab bar bleed | The system material let the warm plan-cover artwork tint the Community/Discover corner by 11 sRGB steps in light appearance. `Color.tabBarBackground` existed as a token and was never applied; it is now, through both `View.opaqueTabBar()` and the appearance proxy iOS 26 actually honours. Measured flat afterwards. |
| Layout specs | `Tools/verify.sh --ui` had 8 failures, every one a spec that had not caught up with a deliberate change: the 13 pt Arabic floor (commit `70aaf51`) moved `discover.card`, `discover.quote` and `discover.reference`; the same commit pinned `ToastHint` to its measured 214 pt, which `reader.hint` still recorded as 262.7; and Phase 4e moved `gift.offerCard` to y 162 so the envelope flap's peak shows. Re-recorded with a note each. Five were invisible until this task removed `ReaderTests`' `XCTSkip`. |
| Widget placeholder icon | **Not fixed — needs `project.yml`.** See below. |

### Still open

**The widget extension ships Xcode's placeholder icon** (brand review item 9). Installing
the app puts a second tile on the home screen drawn as the white construction-grid
placeholder. The widget target has no asset catalog, and giving it one needs one line of
`project.yml` plus an `AppIcon` set for the extension. `project.yml` and `App/` are frozen,
so this is reported, not done.

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
