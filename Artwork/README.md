# Artwork — Scroll the Quran

Original artwork for the app. **The brand mark is the user-supplied logo**, preserved
unmodified in [`Logo/Variants/`](Logo/Variants/README.md) (provenance documented there)
and rendered by `tools/logo.sh` into the app icon, the bare marks and the reader logo
card — so every mark surface in the app is provably the same artwork.
**Everything else here was drawn or generated for this app** — hand-written SVG
geometry rasterised with `librsvg`, procedural ImageMagick work (fractal noise,
metaballs, motion blur, depth-of-field, grain, vignettes), and — for the gift
screens only — **image-model renders made to the owner's own prompts**
(`docs/design/gift-assets-prompts.md`), kept in `src/gift/` and cut into layers by
`tools/gift-assets.sh`. The gift renders include the supplied logo, pressed into the
wax seal, as the prompts asked. There are **no photographs, no traced or derived
third-party artwork, no real-organisation logos, no faces, and no text baked into any
image**. Reference screenshots in `Reference/` were used only to judge composition,
tone and sizing.

Licence for the generated files described below (excluding `Logo/Variants/`):
**CC0 / public domain, original work** — free for
the app to use, modify and ship.

## Rebuilding

```bash
brew install imagemagick librsvg     # magick 7 + rsvg-convert
Artwork/tools/build.sh               # regenerates src/*.svg and every PNG
Artwork/tools/build.sh --vector-gift # ... with the superseded procedural gift art
Artwork/tools/gift-assets.sh         # just the gift layers, from src/gift/
```

`gift-assets.sh` also needs python3 with `numpy`, `scipy` and `Pillow`, and prints the
geometry the app positions the layers by (`PaywallMetrics.openEnvelopeArt`,
`closedEnvelopeArtBody`, `giftCardBody`) — copy those numbers across after a re-cut.

Every layout decision is seeded (`random.Random(n)` in the generators,
`magick -seed`), so a rebuild reproduces the same **composition** exactly:
same cloud shapes, same bead positions, same dune crests, same leaf placement.

It is **not bit-reproducible.** ImageMagick 7 parallelises `+noise` and
`plasma:` across threads and its per-thread RNG streams are not stable at these
image sizes, so the film grain and the fractal fields differ slightly between
runs. Vector-derived assets (app icon, logo mark, glyphs, phone frame,
envelopes) *are* byte-identical on rebuild. Practically: only re-run `build.sh`
when you actually intend to replace the committed PNGs, otherwise `git
checkout` the noise-bearing ones (`PlanCovers/`, `Charity/`) afterwards.
`gift-assets.sh` is the exception: it only resamples and re-tones fixed inputs, so it
*is* bit-reproducible.

| script | what it makes |
| --- | --- |
| `tools/logo.sh` | **app icon, bare marks and logo cards, from the supplied logo** |
| `tools/mark.py` | superseded octagram+crescent geometry, no longer used by the app |
| `tools/compose.py` | superseded app-icon / logo-card / bare-mark SVG documents |
| `tools/gift-assets.sh` | **the gift envelope, card, wax seal and sky, cut from `src/gift/`** |
| `tools/envelope.py` | superseded vector gift envelope + wax seal (`build.sh --vector-gift`) |
| `tools/clouds.py` | superseded procedural cloud sky (`build.sh --vector-gift`) |
| `tools/frame.py` | the iPhone frame overlay |
| `tools/covers.py` | 8 reading-plan covers, 3 charity cards, the scrims |
| `tools/contact_sheet.py` | `contact-sheet.png` |

## The mark

The supplied logo: an **arabesque ring** — a circular band of interlaced vine and
leaf forms, with a lobed finial at each of the four cardinal points and a pointed
one at each diagonal, enclosing an empty circular field. It is a solid silhouette,
so it reads as a ring down to 24 pt and works in solid black on light or solid
white on dark.

`tools/logo.sh` derives every rendition from
`Logo/Variants/logo-transparent.png`: it trims to the ink, re-centres on a square
canvas, and floods a colour through the artwork's own alpha (rather than
`-colorize`, which would leave the original near-black bleeding into the white
variant's edges). One master, one origin, three inks:

| ink | hex | used on |
| --- | --- | --- |
| dark | `#0B0B0D` | light grounds — light app icon, `logo-card-light`, `mark-black` |
| light | `#FFFFFF` | dark grounds — dark/mono app icon, `logo-card`, `mark-white` |

The mark sits at **86 %** of the app-icon canvas and **80 %** of the logo card
(112 pt card, 90 pt mark — `ReaderMetrics`). Phase 4e grew both on the owner's
direction that the mark should read bigger inside and out; at 86 % the ring's
diagonal finials still clear iOS's corner mask with room to spare, which
`AppIcon/icon-masked-60.png` shows at the size it is judged on.

The previous mark — a constructed rub' al-hizb octagram with a crescent in the
central void (`tools/mark.py`, `tools/compose.py`) — is superseded everywhere,
the gift envelope's wax seal included: Phase 4e strikes **this** ring into the
wax (`FeaturePaywall/EnvelopeArt.swift`, two tinted `BrandMark` copies offset
1 pt apart for the emboss), so there is no second mark left in the app.

## Files

### App icon — `AppIcon/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `appicon-1024.png` | 1024×1024 | App Store / default icon. **No alpha.** | `tools/logo.sh`; white logo at 86 % on `src/appicon-ground-gray.svg`, a `#3C3C41 → #2F2F34` radial ground |
| `appicon-180.png` | 180×180 | iPhone @3x preview. No alpha. | downscale of the 1024 |
| `appicon-dark-1024.png` | 1024×1024 | iOS 18 dark icon variant. No alpha. | byte-identical to the default: the app is dark, so both appearances use the one grey ground |
| `icon-masked-60.png` | 180×180 | the shipped icon under iOS's corner mask at 60 pt — the clearance check, not a shipped asset | `tools/logo.sh` |
| `icon-candidates.png` | 720×540 | the three greys the owner was offered (`#5A5A60`, `#3C3C41`, `#2A2A2E`), flat on the top row and masked at 60 pt on the bottom. `#3C3C41` ships. | `tools/logo.sh` |
| `appicon-mono-1024.png` | 1024×1024 | iOS 18 tinted/mono layer | white logo on flat black |

The icon is drawn edge-to-edge with no rounded corner — iOS applies its own mask.

### Logo mark & reader logo card — `Logo/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `mark-white-512.png` | 512×512 | white logo, transparent | `tools/logo.sh` |
| `mark-black-512.png` | 512×512 | black logo, transparent | `tools/logo.sh` |
| `mark-white-64/128/192.png` | 64/128/192 | @1x/@2x/@3x of a 64 pt mark (paywall header) | `tools/logo.sh` |
| `mark-black-64/128/192.png` | 64/128/192 | @1x/@2x/@3x of a 64 pt mark | `tools/logo.sh` |
| `logo-card-112/224/336.png` | 112/224/336 | the reader's centred logo card, @1x/@2x/@3x of 112 pt — white logo in a `#1E1E23` rounded square (corner radius 21.75 % of the side) | `tools/logo.sh` |
| `logo-card-light-112/224/336.png` | 112/224/336 | light-appearance card (`#EFEDE7` ground, black logo) | `tools/logo.sh` |

In app code use **`BrandMark`** (`DesignSystem/Components/BrandMark.swift`), which picks
`LogoMarkWhite` / `LogoMarkBlack` off the colour scheme and falls back to a drawn ring when
the catalog is absent (package previews). The composed cards are shipped so the intended
card proportion is unambiguous.

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

Cut from the renders in `src/gift/` by `tools/gift-assets.sh`: the model paints a fake
checkerboard instead of writing alpha, so every layer is keyed on saturation (the
checkerboard is the only grey thing in frame), opened with a disk to drop the squares,
reduced to its largest component and eroded to lose the painted halo. The paper is then
lifted onto the tones sampled from `Reference/gift-*.png`; the wax is left as rendered.

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `gift-clouds-1179x2556.png` | 1179×2556 | warm sky behind both gift screens, opaque | `sky-raw.png`, per-channel mean and spread matched to the reference's own sky band, scaled to fill and centre-cropped |
| `envelope-closed-1200x900.png` | 1200×900 | closed envelope **with the logo wax seal baked in**, transparent | `closed-sealed-raw.png` keyed; paper spans 96 % of the canvas width, centred (paper bounds `x 24, y 55, 1152 × 790`) |
| `envelope-closed-noseal-1200x900.png` | 1200×900 | the same envelope with no seal, for a code-drawn one | `closed-noseal-raw.png`, keyed by distance from the corner colour (it sits on a beige vignette, not a checkerboard) |
| `envelope-open-1000x1500.png` | 1000×1500 | opened envelope: raised flap, lining and front pocket in one layer, transparent | `open-empty-raw.png` keyed, the flap above the pocket line stretched ×1.85 into a tower for a portrait phone, then padded with a 40 px margin and bottom-anchored |
| `envelope-card-900x1200.png` | 900×1200 | the blank offer card, transparent | `card-blank.png` (real alpha), card body 94 % of the canvas height, centred, its drop shadow spilling into the margin (body bounds `x 55, y 36, 791 × 1128`) |
| `wax-seal-logo-600.png` | 600×600 | **the seal the closed envelope wears**, cut off the paper | `seal-logo-crop-raw.png`, traced — see below |
| `wax-seal-blank-600.png` | 600×600 | the same seal with no emblem, for a code-struck mark | `seal-blank.png` (real alpha) |

The gift-open screen stacks `gift-clouds` → `envelope-open` → `envelope-card` **clipped at
the front pocket's mouth** → `wax-seal-logo`. The mouth is flat across the pocket's top
corners and dips to the point where the two front edges meet; `PaywallMetrics.openEnvelope(...)`
derives it, and every other coordinate, from six fractions of the envelope layer's own
canvas, so replacing the render is one image plus one line.

**Cutting the seal.** No colour key works on it: the gold rim highlights run as light and
as unsaturated as the kraft paper, and the envelope's fold shadow under the rim is as dark
and as saturated as the wax. So the rim is traced — for each of 1440 angles, the furthest
radius that is still gold — and the radial profile is percentile-filtered around the
circle, which keeps the wax's broad scalloped lobes and discards the narrow spikes where
the fold shadow reaches past them. The path is rasterised at 4× for a soft edge and pulled
2 px inside the seal's own contact shadow.

The superseded vector envelopes (`envelope-open-1200x900.png`, `-open-back`, `-open-front`,
`envelope-card-1200x900.png`) are still built by `build.sh --vector-gift` and are what the
app draws when the asset catalog is absent — package previews and host tests.

### Onboarding phone frame — `Frames/`

| file | size | purpose | how generated |
| --- | --- | --- | --- |
| `phone-frame-1179x2556.png` | 1179×2556 | transparent iPhone frame to overlay our own screenshots | `src/phone-frame.svg` |

Structure: the iPhone 17 Pro, drawn from the device's own points — a 402 × 874 pt
screen with a 55 pt corner radius, a 6 pt black border, a 2.5 pt titanium rail
(`#B9B9BE` → `#8E8E93` with a lighter top face), and four side buttons 3.5 pt
proud of the rail (action / volume up / volume down on the left, power on the
right). Those are the same numbers `DeviceFrameMetrics` draws the onboarding
slides' frame from, so the two frames are one device at two scales. `frame.py`
picks a single scale factor — the enclosure plus a button nub on each edge fills
the canvas's width — and multiplies everything by it. **It draws no Dynamic
Island:** the capture behind the aperture carries the real one.

**Screen window: x 33, y 69, 1113 × 2419, corner radius 152**, with the enclosure
itself at y 45, 1179 × 2466. The window is the device's screen, so a 1206 × 2622
capture lands in it edge to edge (0.4601 : 1 against the capture's 0.4600 : 1);
scale to fill and clip to `RoundedRectangle(cornerRadius: 152)`. Do not stretch
it. `python3 Artwork/tools/frame.py` prints those constants on stderr —
`Tools/release/screenshots.sh` carries a copy and must be updated with them.

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

71 image files (PNG deliverables + SVG sources) and 9 generator scripts. The shipped
PNGs are ~21 MB; `src/gift/`'s raw renders are another ~23 MB, and they are kept because
they are the only copy of the input `tools/gift-assets.sh` cuts from. No single shipped
file is over 2.5 MB — the heaviest is `Gift/envelope-closed-1200x900.png` at 2.1 MB.
