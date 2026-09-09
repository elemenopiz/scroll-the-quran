# DesignSystem components — measured geometry

Every number below was read off the reference captures in `Reference/`, which are
**1179 x 2556 px for a 393 x 852 pt screen**, so **pt = px / 3**. Measurements were
taken by scanning runs of constant colour along a row or column of the PNG (the
scan lines are named in the "how" column) rather than by eye, so they are exact to
±1 px = ±0.33 pt. Anything a component hard-codes is in `ComponentMetrics.swift`;
this file is the audit trail for those constants.

Colours are **not** re-measured here — the palette in `Tokens.swift` already carries
its own probe provenance, and components only reference those tokens. The two
exceptions (documented in place) are `TimelineStep.connectorColor` `#D3D1C7`, which
had no token, and the literal black/white of the device bezel and the plan ribbon,
which are the same in both appearances by design.

## Layout spine

| What | px | pt | Source | How |
| --- | --- | --- | --- | --- |
| Page margin | 48 | **16** | home-dark, discover-dark | card left edge at x=48 on every row scan |
| Card width | 1083 | **361** | home-dark | row y=600: `#1E1E23` runs x=48..1130 |
| Deep Study box inset | 72 | **24** | deepstudy-top | quote + historical boxes both x=72..1106 |
| Deep Study box width | 1035 | **345** | deepstudy-top | as above |
| Card inner padding (StatCard) | 54 | **18** | home-dark | card x=48 → flame circle x=102 |
| Row inner padding (RowLink) | 48 | **16** | home-dark | card x=48 → icon circle x=96 |

## Pills and capsules

| Component | Property | px | pt | Source | How |
| --- | --- | --- | --- | --- | --- |
| `PrimaryPillButton` | height (onboarding) | 168 | **56** | onboarding-hook | black bbox y=2238..2405 |
| `PrimaryPillButton` | height (paywall) | 195 | **65** | paywall-trial | black bbox y=2040..2234 |
| `PrimaryPillButton` | height (Home settings) | 156 | **52** | home-dark | white bbox y=2064..2219 |
| `PrimaryPillButton` | corner | — | capsule | onboarding-hook | corner inset reaches 0 at dy = h/2 = 84 px |
| `PrimaryPillButton` | onboarding side inset | 157 | **52** | onboarding-hook | pill x=156..1022 on a 1179 px screen |
| `PrimaryPillButton` | paywall side inset | 48 | **16** | paywall-trial | pill x=48..1130 |
| `OutlinePillButton` | height | 172 | **57** (57.3) | onboarding-hook | bbox y=2038..2209 (border included) |
| `OutlinePillButton` | border | 3 | **1** | onboarding-hook | row y=2093: `#BBBBBD` runs x=160..163 |
| CTA stack spacing | gap | 29 | **10** | onboarding-hook | outline bottom 2209 → pill top 2238 |
| `Chip` (`.theme`) | height | 79 | **26** | discover-dark | `#303035` bbox y=420..498 |
| `Chip` (`.theme`) | width ("Joy in Trials") | 308 | 103 | discover-dark | x=436..743 |
| `Chip` (`.crossReference`) | height | 90 | **30** | discover-dark | col x=200 across the chip |
| `CapsuleIconGroup` | height | 106 | **36** (35.3, rounded up) | reader-dark | col x=80: `#1E1E23` y=199..304 |
| `CapsuleIconGroup` | glyph | 40 | **14** | reader-dark | dice glyph x=64..103 |
| `CapsuleIconGroup` | left margin | 30 | **10** | reader-dark | capsule starts x=30 |
| `OfflineBadge` | height | 47 | **16** | translation-sheet | `#30D158` bbox y=451..497 |

## Circles

| Component | px | pt | Source | How |
| --- | --- | --- | --- | --- |
| `CircleIconButton` (Deep Study header) | 132 | **44** | deepstudy-top | both buttons y=177..308, x=48..179 / 999..1130 |
| `TimelineStep` node | 120 | **40** | paywall-trial | all three nodes y-extent 120, x=48..167 |
| `TimelineStep` connector | 6 wide | **2** | paywall-trial | row y=990: `#D3D1C7` x=108..113 |
| `RowLink` icon | 120 | **40** | home-dark | `#303035` x=96..215, y=1560..1679 |
| `StatCard` emblem | 168 | **56** | home-dark | flame circle x=102..269, y=428..595 |

## Cards, boxes and bars

| Component | Property | px | pt | Source | How |
| --- | --- | --- | --- | --- | --- |
| `StatCard` (streak) | height | 529 | 176 | home-dark | col x=70: card y=394..922 |
| `StatCard` (progress) | height | 409 | 136 | home-dark | col x=70: card y=1023..1431 |
| `RowLink` | height | 200 | **67** (66.7, rounded up) | home-dark | col x=70: card y=1520..1719 and y=1796..1995 |
| Card vertical gap | between rows | 77 | 26 | home-dark | 1719 → 1796 |
| Card vertical gap | between stat cards | 101 | 34 | home-dark | 922 → 1023 |
| `ProgressBar` | height | 30 | **10** | home-dark | col x=600: `#303035` y=1273..1302 |
| `ProgressBar` | inset in card | 54 | 18 | home-dark | row y=1287: track x=103..1076 |
| `ReviewCard` | accent bar | 9 | **3** | onboarding-reviews | row y=1000: `#FFC733` x=84..92 |
| `TintedSectionBox` (quote) | height | 425 | 142 | deepstudy-top | `#231E19` y=726..1150 |
| `TintedSectionBox` (historical) | height | 355 | 118 | deepstudy-top | `#0F2130` y=2045..2399 |
| DYK box on Discover | inset inside card | 60 | **20** | discover-dark | card x=48 → box x=108 |
| `ToastHint` | height | 182 | **61** (60.7, rounded up) | reader-dark | bbox y=2014..2195 |
| `ToastHint` | width | 642 | 214 | reader-dark | bbox x=150..791 |
| `ActionIconRow` | glyph | ~72 | **24** | discover-dark | four icons centred at x≈265/478/700/914 |
| Sheet divider | thickness | 3 | **1** | translation-sheet | col x=600: `#38383B` y=387..389 |

## Device mockup (`PhoneFrame`)

| Property | px | pt | Source | How |
| --- | --- | --- | --- | --- |
| Outer width | 740 | **247** | onboarding-slide2-plans | bbox x=219..959 |
| Screen width | 665 | **222** | onboarding-slide2-plans | row y=1400: content x=256..920 |
| Bezel | 30 | **10** | onboarding-slide2-plans | outer 226 → screen 256 |

The mockup renders a real 393 pt screen at 222 pt, i.e. `contentScale ≈ 0.565`.

## Verse type (`VerseText`)

Line pitch was measured by grouping the rows that contain ink in the verse block and
differencing the group tops. Source Serif 4's line box is **1.371 em** (hhea
ascent 1036, descent −335, gap 0, upm 1000), so the point size below is the one whose
natural leading lands closest to the reference pitch while keeping the same ink height.

| Surface | Reference pitch | English size | Arabic size (0.58x) | Source |
| --- | --- | --- | --- | --- |
| `.reader` | 91, 90 px → **30 pt** | **23** | 13.3 | reader-dark, rows 1227/1318/1408 |
| `.deepStudy` | 80, 80, 80 px → **26.7 pt** | **20** | 11.6 | deepstudy-top, rows 795/875/955/1035 |
| `.discover` | 61, 60 px → **20 pt** | **16** | 9.3 | discover-dark, rows 717/778/838 |
| `.widget` | not in the references | **15** | 8.7 | derived: one step below Discover |

`VerseText.arabicRatio = 0.58` — the middle of CLAUDE.md rule 5's 55–60 % band.
KFGQPC Uthmanic Hafs has a 2048 upm with a 1.758 em line box (hhea ascent 2400,
descent −1200), because the pause marks and superscript alefs sit well outside the
letter body; `ArabicAccentText` therefore adds `lineSpacing(size * 0.35)` on top of
that so stacked marks never collide between lines.

## Known gaps

- Corner radii are **not** re-derived here. The reference's corners are continuous
  (squircle) profiles, and fitting one from an antialiased edge is not reliable to
  better than a few points; `Radius.cardSmall/card/cardLarge` (24/28/32) were already
  measured in Phase 1 and every component references those tokens.
- `WheelPicker3` has no reference capture — no shipped screen in `Reference/` shows a
  wheel. Its row height and 170 pt overall height follow the iOS wheel convention.
- `PlanCard` proportions come from the scaled mockup inside onboarding-slide2 (0.565x),
  so its paddings are conventional rather than measured; the ribbon angle (−45°) and
  the black-on-white treatment are taken from the capture.
