# Artwork — Scroll the Quran

Original artwork for the app. **Everything here was drawn or generated from
scratch in this repo** — hand-written SVG geometry rasterised with `librsvg`,
plus procedural ImageMagick work (fractal noise, metaballs, motion blur,
depth-of-field, grain, vignettes). There are **no photographs, no traced or
derived third-party artwork, no real-organisation logos, no faces, and no text
baked into any image**. Reference screenshots in `Reference/` were used only to
judge composition, tone and sizing.

Licence for every file below: **CC0 / public domain, original work** — free for
the app to use, modify and ship.

## Rebuilding

```bash
brew install imagemagick librsvg     # magick 7 + rsvg-convert
Artwork/tools/build.sh               # regenerates src/*.svg and every PNG
```

`build.sh` is deterministic: all randomness is seeded, so a rebuild reproduces
the same pixels.

| script | what it makes |
| --- | --- |
| `tools/mark.py` | the mark geometry (interlaced octagram + crescent) |
| `tools/compose.py` | app-icon / logo-card / bare-mark SVG documents |
| `tools/envelope.py` | closed + opened gift envelope, wax seal |
| `tools/clouds.py` | the warm-beige cloud sky |
| `tools/frame.py` | the iPhone frame overlay |
| `tools/covers.py` | 8 reading-plan covers, 3 charity cards, the scrims |
| `tools/contact_sheet.py` | `contact-sheet.png` |

## The mark

A **rub' al-hizb octagram** — two squares of equal size, one rotated 45°, woven
over-and-under at their eight crossings — with a **crescent** in the central
octagonal void. It is pure construction geometry (`tools/mark.py`), so it scales
cleanly, reads as a ring at 24 pt, and works in solid black on light or solid
white on dark. It shares no shape language with any existing app's mark.

## Files

### App icon — `AppIcon/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `appicon-1024.png` | 1024×1024 | App Store / light icon. **No alpha.** | `src/appicon.svg`; black mark at 77 % on a warm off-white radial ground |
| `appicon-180.png` | 180×180 | iPhone @3x preview. No alpha. | downscale of the 1024 |
| `appicon-dark-1024.png` | 1024×1024 | iOS 18 dark icon variant. No alpha. | `src/appicon-dark.svg`; white mark on a near-black radial ground |
| `appicon-mono-1024.png` | 1024×1024 | iOS 18 tinted/mono layer | `src/appicon-mono.svg`; white mark on flat black |

The icon is drawn edge-to-edge with no rounded corner — iOS applies its own mask.

### Logo mark & reader logo card — `Logo/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `mark-white-512.png` | 512×512 | white line-art mark, transparent | `src/mark-white.svg` (stroke 15.5, optically matched to the black weight) |
| `mark-black-512.png` | 512×512 | black line-art mark, transparent | `src/mark-black.svg` (stroke 14) |
| `mark-white-64/128/192.png` | 64/128/192 | @1x/@2x/@3x of a 64 pt mark (paywall header) | same SVGs |
| `mark-black-64/128/192.png` | 64/128/192 | @1x/@2x/@3x of a 64 pt mark | same SVGs |
| `logo-card-96/192/288.png` | 96/192/288 | the reader's centred logo card, @1x/@2x/@3x of 96 pt — white mark in a `#1E1E23` rounded square (corner radius 21.75 % of the side) | `src/logo-card.svg` |
| `logo-card-light-96/192/288.png` | 96/192/288 | light-appearance card (`#EFEDE7` ground, black mark) | `src/logo-card-light.svg` |

Prefer the bare `mark-*` PNGs plus a SwiftUI `RoundedRectangle` from
`DesignSystem` — the composed cards are provided so the intended proportion is
unambiguous.

### Paywall trial-timeline glyphs — `Icons/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `icon-lock-64/128/192.png` | 64/128/192 | "Today" step | `src/glyph-lock.svg`, white on transparent |
| `icon-bell-64/128/192.png` | 64/128/192 | "Day 5" step | `src/glyph-bell.svg` |
| `icon-check-64/128/192.png` | 64/128/192 | "Day 7" step | `src/glyph-check.svg` |

These are deliberately SF-Symbols-shaped. **SF Symbols `lock.fill`, `bell.fill`
and `checkmark` cover the same need** and will track Dynamic Type and the system
weight automatically — prefer them and treat these PNGs as the fallback if the
paywall needs a fixed optical size.

### Gift screens — `Gift/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `gift-clouds-1179x2556.png` | 1179×2556 | warm beige sky behind the gift screens | `tools/clouds.py`: circle metaballs (body + crown-scallop tiers) blurred and re-levelled into puffy silhouettes, roughened and density-varied by two fractal-noise fields, top-lit by an offset blur of the same mask, over a `#E7E0CD → #D5CCB2` gradient, plus grain |
| `envelope-closed-1200x900.png` | 1200×900 | closed envelope, transparent | `src/envelope-closed.svg`: four paper panels meeting at centre, flap over the top, fold shadows, gold wax seal |
| `envelope-open-1200x900.png` | 1200×900 | opened envelope with a blank card in the slot | `src/envelope-open.svg` (= back + card + front composited) |
| `envelope-open-back-1200x900.png` | 1200×900 | back panel + raised flap only | `src/envelope-open-back.svg` |
| `envelope-open-front-1200x900.png` | 1200×900 | front pocket + seal only | `src/envelope-open-front.svg` |
| `envelope-card-1200x900.png` | 1200×900 | the blank inner card on its own | `src/envelope-card.svg` |

To put live SwiftUI content inside the opened envelope, stack
`envelope-open-back` → your card view → `envelope-open-front`. The card slot is
the rect **x 250, y 110, w 700, h 530, corner radius 24** in the 1200×900
coordinate space; the front pocket occludes everything below y = 380.

The wax seal is a jittered Catmull-Rom blob with radial-gradient gold shading
and the app mark struck into a recessed disc (a light offset copy under a dark
copy gives the emboss).

### Onboarding phone frame — `Frames/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `phone-frame-1179x2556.png` | 1179×2556 | transparent iPhone frame to overlay our own screenshots | `src/phone-frame.svg` |

Structure: a 12 px titanium rail (multi-stop linear gradient), an 18 px black
bezel, side-button nubs, and a black Dynamic Island pill (375×111 at x 402,
y 66). Outer corner radius 190; aperture corner radius 160.

**Screen window: x 30, y 30, 1119 × 2496.** That window is 0.4484 : 1 while a
real screenshot is 0.4613 : 1, so scale the screenshot to *fill* the window and
clip it to a `RoundedRectangle(cornerRadius: 160)` — a ~1.5 % vertical crop,
invisible in practice. Do not stretch it.

### Reading-plan covers — `PlanCovers/`

All 1200×800, no text baked in.

| file | subject | how generated |
| --- | --- | --- |
| `plan-mushaf-page-1200x800.png` | macro of an open page | word-grouped cursive-looking strokes (shapes, never letterforms) + diacritic specks on a cream gradient, gutter shadow, depth-of-field mask keeping a sharp band across the middle |
| `plan-prayer-beads-1200x800.png` | misbaha | two catenary strands of radial-gradient spheres, the rear strand blurred for depth, warm glow, heavy vignette |
| `plan-geometric-tile-1200x800.png` | girih screen | lattice of {8/3} star polygons at 300 px pitch plus rotated squares, thin ink strokes, diagonal light wash |
| `plan-dawn-light-1200x800.png` | dawn sky | five-stop sky gradient, radial sun glow, horizon haze, scattered soft cloud slivers, blur + grain |
| `plan-lantern-1200x800.png` | pierced lantern | hexagonal lantern silhouette with 20 pierced eight-point stars, screen-composited bloom pass |
| `plan-ink-wash-1200x800.png` | sumi-e wash | three tapered brush-stroke paths as the silhouette, a motion-blurred fractal-noise field as the dry-brush alpha, ink gradient on laid paper |
| `plan-desert-dune-1200x800.png` | dunes | five layered dune curves with per-band gradients and crest highlights, low sun, grain |
| `plan-olive-branch-1200x800.png` | olive branch | leaves placed along the tangent of a cubic Bézier stem, three depth layers (two blurred), on a warm neutral ground |
| `plan-cover-scrim-1200x800.png` | — | reusable dark overlay: clear for the top ~45 %, ramping to ~80 % black at the bottom edge |

Composite `plan-cover-scrim` over any cover (`.overlay`, normal blend) so white
titles read; covers themselves are left clean so they can also be used
full-bleed or with a custom gradient.

### Charity card imagery — `Charity/`

All 1200×600, abstract, no real organisations, no faces.

| file | subject | how generated |
| --- | --- | --- |
| `charity-giving-hands-1200x600.png` | two open palms cupping a light | constructed hand silhouettes (palm path + capsule fingers + thumb, mirrored and rotated inward), warm radial glow, rising motes, bloom pass |
| `charity-harvest-wheat-1200x600.png` | wheat field | 32 procedurally built stalks (curved stem, tapered two-column grain heads with awns) in two depth layers |
| `charity-clean-water-1200x600.png` | drop and ripples | eleven jittered ripple ellipses with paired light/dark strokes and a falling drop, over a cool gradient |
| `charity-card-scrim-1200x600.png` | — | reusable dark overlay, same ramp as the plan scrim |

### Contact sheet

`contact-sheet.png` (1500×2709) shows every asset in context — envelopes on the
cloud sky, the frame over a stand-in screenshot, a cover with the scrim applied.

## Totals

64 image files (PNG deliverables + SVG sources) and 8 generator scripts,
**17.7 MB** on disk (limit 25 MB). The heaviest single file is
`Gift/gift-clouds-1179x2556.png` at 2.7 MB.
