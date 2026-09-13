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

## Discover card: the whole verse fits — Phase 4m, 2026-09-13

iPhone 17 Pro (`ScrollSim-3e`, iOS 26), `SCROLL_FIXED_DATE=2026-09-14`, `SCROLL_CAPTURE_SETTLE=6`.

Owner: "on the discover tab, ideally the entirety of the verse fits on the card. the
meaning/did you know can be cut off." Phase 4i's four-line quote slot elided most passages;
Phase 4m gives the quote the lines it actually needs and re-divides what is left.

| id | Phase 4i | Phase 4m | threshold | delta |
| --- | ---: | ---: | ---: | ---: |
| `discover-dark` | 0.0361800 | 0.0380826 | 0.14 | +0.0019 |

### What changed, and why the score moved the way it did

The card's height, the chip, the title, the cross-reference row, "Deep study ›" and the
action row are **exactly where Phase 4i put them** — `DiscoverCardLayout.cardHeight` is
unchanged at 607.365 pt and the layout spec re-records only two rows. What moved is the
split inside the body: `DiscoverCardLayout.bodyBudget` (335.5 pt, Phase 4i's three slots
totalled) is now divided per card by
`DiscoverCardLayout.body(for:meaning:didYouKnow:width:)`. On the capture card
(Al-Ankabut 29:68-69) the quote goes from four elided lines to its full six and MEANING
drops from four lines to two, which is the whole of the +0.0019: the reference (James 1:2-3,
a short passage) draws three quote lines and four of meaning, so a longer quote reads as
residue against it. It is the deviation the owner asked for.

### The plan over the 326 units

| | count |
| --- | ---: |
| quote at 16 pt | 310 |
| quote at 15 pt | 9 |
| quote at 14 pt | 7 |
| MEANING 4 lines / 3 / 2 / dropped | 153 / 82 / 87 / 4 |
| DID YOU KNOW dropped | 89 |
| quote still truncated | 2 |

MEANING is dropped on `18:1-10`, `2:285-286`, `31:13-19`, `49:11-13`. The two units whose
quote still ends in a "…" — the brief's escape hatch, and the list the owner asked for so
they can decide whether to narrow the passage in `Content/discover.json` — are
**`31:13-19`** (215 words, 18 lines at 14 pt against the 17 the body holds) and
**`18:1-10`** (178 words). They are asserted by name in `OverflowLedger`, so a content
change that adds a third fails the gate.

Captured proof (`.build/snapshots/discover-card-*.png`): `5:8` (44 words — five quote
lines, three of MEANING, the DID YOU KNOW box intact), `2:285-286` (145 words — sixteen
lines at 15 pt, both prose sections gone, the passage whole) and `31:13-19` (215 words —
seventeen lines at 14 pt and the one ellipsis). All three put the card's edges exactly
where card 0 does.

## Phase 4h — the phone frame, 2026-09-12

iPhone 17 Pro (`ScrollSim-3d`, iOS 26), `SCROLL_FIXED_DATE=2026-09-14`. Five screens
re-measured after the funnel's device mockup was rebuilt from the hardware's own numbers
and the gift screen's OFF pill was dropped clear of the "33%". One threshold moves.

| id | Phase 4d | Phase 4h | threshold | verdict |
| --- | ---: | ---: | ---: | --- |
| `onboarding-slide1` | 0.0953 | 0.1032 | 0.12 | pass — **accepted deviation**, bezel thickness |
| `onboarding-slide2` | 0.1248 | 0.1360 | 0.13 → **0.14** | **accepted deviation**, bezel thickness on top of the plan covers |
| `onboarding-slide3` | 0.0571 | 0.0682 | 0.12 | pass — **accepted deviation**, bezel thickness |
| `onboarding-slide4` | 0.0711 | 0.0808 | 0.12 | pass — **accepted deviation**, bezel thickness |
| `gift-open` | 0.0624 | 0.0654 | 0.10 | pass — the OFF pill moved 8 pt down, deliberately |

**What changed.** The slides' frame was a flat black rounded rectangle with an oversized
Dynamic Island drawn on top of the capture's own one, and the capture inside was scaled to
*fill* a 1119 x 2496 window whose aspect did not match it: the clock lost its top and the
outer tab labels read "mmunity" and "The Qu". It is now the iPhone 17 Pro drawn from
`DeviceFrameMetrics` — 402 x 874 pt of glass at a 55 pt radius, a 6 pt black border, a
2.5 pt titanium rail (`#B9B9BE` → `#8E8E93`), action / volume / power buttons 3.5 pt proud
of it, a soft ground shadow, and no island of its own. The four bundled captures are whole
screens again (690 x 1500 px, 4.0 MB → 1.4 MB) and `MockupArt` *fits* rather than fills, so
nothing is cropped. The same numbers generate `Artwork/src/phone-frame.svg`, so the
marketing frame and the in-app frame are one device at two scales.

**Accepted deviation: the reference's bezel is twice the hardware's.** The reference's
frame is a stylised mockup, not the phone the app runs on. Measured off
`onboarding-slide1-feed.png`: its enclosure is 243.3 x 497.7 pt (a 0.489 : 1 body — no
iPhone is that wide for its height) with a 10.6 pt bezel, where an iPhone 17 Pro's is 8.5
device pt, 4.7 at this scale. Both cannot be had. What is matched is the enclosure's own
silhouette — rows 238...736 on the two-line slides, 254...752 on slide 2, Continue still on
746 — and the screen window's registration, which lands within a point of the reference's
own glass columns. What is left is a ~4.6 pt ring down each side and ~6 pt top and bottom
where the reference shows black bezel and ours shows screen content. Under the sigma-6 blur
that ring is most of the residue: on `onboarding-slide3` the 18 pt strips just inside the
reference's edges score 0.11 against a whole-screen 0.0682, while the band *outside* the
phone (where the new shadow lives) is closer to the reference than the old frame was
(mean luminance 236.2 against the reference's 238.3; the old frame's was 231.9).

Chasing it would mean drawing a phone that does not exist, which is the opposite of the
brief ("the iPhone visualization in the onboarding needs to be cleaned up a bit so it's
more prim and proper"). The frame now reads as a real device: thin rim, real buttons, a
shadow, one Dynamic Island rather than two, and a status-bar clock and four tab labels that
are not sliced.

**`onboarding-slide2` also loses its status bar.** iOS dims the parent screen to *black*
behind a sheet; the reference's slide 2 shows a light grey band with the clock legible on
it. `render-mockups.sh` trims that 236 px band and pads the same 236 px of the sheet's own
`#FAFAFC` back, so the plans list reads as filling the screen — near-white against the
reference's grey is a much smaller error than black would be, but it is an error, and it
sits on top of the plan-cover residue this screen already carried. 0.1360 against a 0.13
ceiling, so the ceiling goes to 0.14.

**`gift-open`: the OFF pill.** "the OFF under 33% needs to be moved down a bit" (owner).
`PaywallMetrics.offPillTop` 270 → 278. Geo Bold sets the digits 5 pt deeper than the
reference's face, so at 270 the pill's white outline still cut 5.8 pt into a 49.3 pt digit
(12 %); at 278 it clears the ink by 2.2 pt and still leaves 8.7 pt to the "+3 day trial"
pill. The reference's own pill overlaps its digits slightly more than ours now does, which
is the whole of the +0.0030.
## Discover card polish — Phase 4i, 2026-09-12

iPhone 17 Pro (`ScrollSim-3e`, iOS 26), `SCROLL_FIXED_DATE=2026-09-14`, `SCROLL_CAPTURE_SETTLE=6`.
Six screens re-scored; **no threshold changed**, and every affected screen improved.

| id | Phase 4d | Phase 4i | threshold | delta |
| --- | ---: | ---: | ---: | ---: |
| `discover-dark` | 0.0591492 | 0.0361800 | 0.14 | −0.0230 |
| `deepstudy-top` | 0.0663536 | 0.0640829 | 0.14 | −0.0023 |
| `deepstudy-mid` | 0.0571212 | 0.0571212 | 0.14 | ±0.0000 |
| `deepstudy-crossrefs` | 0.0561442 | 0.0561442 | 0.14 | ±0.0000 |
| `deepstudy-bottom` | 0.0495345 | 0.0495345 | 0.14 | ±0.0000 |
| `reader-dark` | 0.0389370 | 0.0386839 | 0.05 | −0.0003 |

### Accepted deviations recorded here

**CLAUDE.md rule 5 has one exception, and this is it: the Discover card shows no Arabic.**
Rule 5 says every verse surface carries the muted Uthmani line above the English. The owner
removed it from the Discover card on 2026-09-12 (brief amendment 2). The card is the one
fixed-height surface in the app — four English lines, four of meaning, three of did-you-know,
all in a 594 pt box — and the accent line only fitted there by being elided, which rule 5
forbids outright. **The layer is unchanged everywhere else**: the reader page, the Deep Study
quote box, the share card and the widget all still draw it, still at `Typography.arabicAccent`
in `Tokens.textTertiary`, still RTL, still `accessibilityHidden`, still never transliterated.
`UITests/DiscoverTests.testTheCardCarriesNoBadgeAndNoArabic` is the guard.

**No translation badge on the Discover card or the Deep Study header.** The reference draws
`KJV` under both titles and we drew `ITANI`; the owner took it off both (amendment 2) because
the reader toolbar's translation pill is the control that names and changes the translation
and a second, untappable copy of the same string reads as noise. `PassagePresentation`'s
`translationTag` went with it. Costs a small band of difference under each title; both screens
still improved on the round.

**The Deep Study header title is 32 pt where the reference's is ~38 pt.** The owner asked for
the Discover card's title size on both for consistency. Measured off the references: the card's
"James 1:2-3" is a 32.2 pt em (65 px of cap height against Source Serif 4's 670/1000, and a
487 px ink box against a 5050/1000 em advance); the Deep Study one is 77 px of cap, a 38.3 pt
em. Ours is 32 on both.

**The Discover quote slot is four lines where the reference draws three.** The fixed-slot
amendment asks for four, so MEANING, the did-you-know box, the chips and "Deep study ›" all
sit about 21 pt lower than the reference draws them. The card's own edges still match: ours
runs 120.6..714.9 pt on the normalised canvas against the reference's 120..714, and the action
row lands within 1.3 pt. The cost shows up between "Deep study ›" and the icons, which is
29 pt of air where the reference has 57.

**The action icons are 21 pt, not the brief's 26.** Measured rather than estimated: the
reference's row ink is 22.4 pt tall and its bookmark glyph 14.0 pt wide, which is a 21 pt SF
Symbol. Their centres are 88.5 / 160.3 / 232.5 / 304.3 pt — 72 pt apart, centred on the card's
own centre line rather than spread across its width. The brief's 26 pt drew them 22 % too
large; 24 pt (the old `Metrics.actionIcon`, still the default for every other caller) drew them
14 % too large.

### Fixed slots — the thing the owner actually asked for

"When you scroll the verses on the original app all of them have the same placement and look
polished; on ours it's not the case." Every card is now `DiscoverCardLayout.cardHeight` tall
with the same slots, so the pager lands identically on each one.
`Packages/ScrollKit/Tests/FeatureDiscoverTests/DiscoverCardLayoutTests.swift` lays all **326**
Discover units out with the real registered Source Serif at the real content width and asserts
one card height for all of them; `UITests/DiscoverTests.testEveryCardHasTheSameGeometry` asserts
the same of the running views. Captured proof, via the new `--discover-index N` launch option
(`.build/snapshots/discover-card<N>-<appearance>.png`): card 0 (Al-Ankabut 29:68-69, two ayat),
card 150 (Luqman 31:13-19, seven ayat — the corpus's longest passage) and card 247
(At-Tawbah 9:119, the shortest) all put the card's top edge at 123.7 pt and its bottom at
733.3 pt of the 874 pt simulator, in both appearances.

## Full sweep — Phase 4d, 2026-09-12

iPhone 17 Pro (`ScrollSim-3d`, iOS 26), `SCROLL_FIXED_DATE=2026-09-14`. 27 screens, all
under threshold, **no threshold changed and no new accepted deviation**. Phase 4d is the
pre-submission audit-fix pass (`docs/store/audit-findings.md`), and the point of this table
is that nine findings were closed without the design moving.

| id | Phase 4b | Phase 4d | threshold | delta |
| --- | ---: | ---: | ---: | ---: |
| `onboarding-hook` | 0.0485 | 0.0490827 | 0.08 | +0.0006 |
| `onboarding-signin` | 0.0787 | 0.0792698 | 0.08 | +0.0006 |
| `onboarding-slide1` | 0.0952 | 0.0953370 | 0.12 | +0.0001 |
| `onboarding-slide2` | 0.1245 | 0.1248200 | 0.13 | +0.0003 |
| `onboarding-slide3` | 0.0567 | 0.0571480 | 0.12 | +0.0004 |
| `onboarding-slide4` | 0.0705 | 0.0710667 | 0.12 | +0.0006 |
| `onboarding-reviews` | 0.0739 | 0.0741706 | 0.10 | +0.0003 |
| `paywall-trial` | 0.0346 | 0.0350887 | 0.06 | +0.0005 |
| `paywall-plans` | 0.0340 | 0.0340461 | 0.08 | +0.0000 |
| `gift-closed` | 0.0424 | 0.0423650 | 0.10 | −0.0000 |
| `gift-open` | 0.0624 | 0.0624148 | 0.10 | −0.0000 |
| `community-dark` | 0.0539 | 0.0538826 | 0.10 | −0.0000 |
| `discover-dark` | 0.0591 | 0.0591492 | 0.14 | +0.0000 |
| `deepstudy-top` | 0.0664 | 0.0663536 | 0.14 | −0.0000 |
| `deepstudy-mid` | 0.0571 | 0.0571212 | 0.14 | +0.0000 |
| `deepstudy-crossrefs` | 0.0561 | 0.0561442 | 0.14 | +0.0000 |
| `deepstudy-bottom` | 0.0491 | 0.0495345 | 0.14 | +0.0004 |
| `reader-dark` | 0.0389 | 0.0389370 | 0.05 | +0.0000 |
| `reader-light` | 0.0642 | 0.0641577 | 0.08 | −0.0000 |
| `translation-sheet` | 0.0411 | 0.0419785 | 0.10 | +0.0009 |
| `notes-sheet` | 0.0236 | 0.0236446 | 0.12 | +0.0000 |
| `home-dark` | 0.0638 | 0.0638344 | 0.10 | +0.0000 |
| `home-light` | 0.1021 | 0.1021540 | 0.16 | +0.0000 |
| `verse-search` | 0.1077 | 0.1077010 | 0.16 | +0.0000 |
| `plans-sheet` | 0.1927 | 0.1927420 | 0.20 | +0.0000 |
| `plan-detail` | 0.1382 | 0.1382070 | 0.145 | +0.0000 |
| `tabbar-dark` | 0.0375 | 0.0374815 | 0.12 | −0.0000 |

Three changes could have moved these and did not, which is the thing worth recording:

**Dynamic Type (A11Y-1) moves nothing.** `Font.body` and `Font.capsLabel` now scale
through `UIFontMetrics`, and `UIFontMetrics.scaledValue(for:)` returns its argument
unchanged at the `large` content size every capture is taken at. Every screen was measured
before and after the commit and matched to four decimals. The 200 % cap is a WCAG 1.4.4
decision, not a snapshot one.

**The tertiary text split (A11Y-2) is the whole of the visible delta.** `textTertiary`
(#8E8E93 / #7D7D7E) keeps its measured value for the decorative Arabic layer, the chevrons
and the separators; 22 pieces of read text moved to `textTertiaryReadable`
(#6C6C70 / #9A9A9E), which is darker in light and lighter in dark. The largest cost is
`translation-sheet` at +0.0009 — four licence blocks are most of that screen. **No measured
card, sheet or page ground changed**: this is a new token, not a re-measured one.

**The gift offer's legal footer (IAP-2) is under the mask.** Terms / Privacy / Restore
Purchases sit at y 819 in reference space, and `compare.sh` masks the bottom 34 pt, so
`gift-open` reads 0.0624148 against 0.0624227 before it. It is a real, visible, tappable
row on the device — it is simply below the band the score looks at. Recorded here so it is
not mistaken for a row that was never added.

**The purchase-state banner (IAP-1) never appears in a capture.** `PaywallNoticeView` is
drawn only when a purchase or a restore has left something to say, and a `--screenshot`
route makes no purchase. Its three positions (`PaywallMetrics.noticeTop` 496,
`sheetNoticeTop` 424, `giftNoticeTop` 118) are each in a band the reference leaves empty;
`UITests/PaywallStateTests.swift` asserts the placement rather than a capture.

### Dynamic Type walk — Phase 4d

Not scored; there is no reference for a screen at a larger content size. Captures in
`.build/snapshots/../dynamictype/`:

| capture | verdict |
| --- | --- |
| `reader-extra-extra-extra-large.png`, `reader-accessibility-extra-large.png` | clean; the toolbar's translation and surah pills truncate on the line limits they already had |
| `home-extra-extra-extra-large.png`, `home-accessibility-extra-large.png` | clean; row titles and subtitles grow and the rows grow with them |
| `deepstudy-accessibility-extra-large.png`, `deepstudy-ax5.png` | clean and scrollable at every size |
| `discover-extra-extra-extra-large.png`, `discover-accessibility-extra-large.png` | the paged card's verse overflows the card. **Pre-existing** — it is `serifItalic`, which scaled before Phase 4d; `discover-ax3-BEFORE.png` is the A/B from the previous build. `FeatureDiscover` is outside 4d's ownership. |
| `deepstudy-ax5.png` | A11Y-6 confirmed: English ~3x, Arabic fixed, so the ~58 % ratio is gone. Nothing clips; the layer is decorative and VoiceOver-hidden. A design call, not a defect. |

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

### Phase 4k — owner-generated covers and charity cards (2026-09-12)

Every plan cover and charity card pixel changed (18 photographic covers, 3 cards; `Artwork/src/covers`, `Artwork/src/charity`). Measured on a cold `ScrollSim-3c` with `SCROLL_CAPTURE_SETTLE=12`:

| id | RMSE | threshold | verdict |
|---|---|---|---|
| `plans-sheet` | 0.1995 | 0.22 (was 0.20) | accepted deviation — photographic covers, 18 plans vs the reference's list |
| `plan-detail` | 0.1584 | 0.17 (was 0.145) | accepted deviation — the first-page cover replaces the procedural one |
| `home-dark` | 0.0638 | 0.10 | pass (no plan active in the fixture, so no cover shows) |
| `home-light` | 0.1022 | 0.12 | pass |
| `community-dark` | 0.0551 | 0.10 | pass — giving-hands card |
| `onboarding-slide2` | 0.1360 | 0.14 | pass (mockup rendered by Phase 4h) |

Note for the release sweep: the slide mockups still show the pre-rename reader pill (CLEAR) and the pre-plans titles; re-run `Tools/snapshot/render-mockups.sh` after the final merge and re-measure the four slides.

### Phase 4l — covers cropped to the subject (2026-09-13)

The 18 renders were authored with their subject **off-centre** (`docs/design/asset-prompts.md`
put it in the lower-left or lower-right third so a title could sit over a calm top), and the
app was centre-cropping them: the lantern lost its left half, the mushaf hung off the right
edge, the dune's crest sat in the corner. `PlanCoverFocal.swift` now carries a per-slug crop
anchor and `PlanCoverImage` fills, shifts and clips on it, so the overflow is trimmed on the
side *away* from the subject. Same assets, same sizes — only the window moved. The crops are
laid out side by side in `docs/design/cover-crops-contact.jpg` (current centre square | focal
square | focal 1.95:1 hero, per slug).

Measured on `ScrollSim-3d` with `SCROLL_CAPTURE_SETTLE=12`:

| id | RMSE before (4k) | RMSE after | threshold | verdict |
|---|---|---|---|---|
| `plans-sheet` | 0.1995 | 0.2035 | 0.22 | pass — unchanged ceiling |
| `plan-detail` | 0.1584 | 0.1613 | 0.17 | pass — unchanged ceiling |
| `home-dark` | 0.0638 | 0.0638 | 0.10 | pass — no plan active in the fixture, so no cover shows |

Both cover screens move **up** by ~0.003–0.004, and that is expected rather than a
regression: the reference is Scroll the Bible's own licensed stock photographs, so the score
measures how closely our tone blocks happen to land on theirs, not whether our crop is good.
Moving the window off centre puts the subject's own luminance where the reference has sky or
wall. The captures were read next to the references — `plans-sheet` now shows the Juz Amma
lantern whole and centred in its tile where it used to be sliced at the left edge, and
`plan-detail`'s hero holds the whole mushaf instead of clipping its foot. The thresholds are
left where Phase 4k set them.
