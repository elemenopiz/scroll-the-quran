# Gift screen artwork — image-generation brief

The gift ("one-time offer") screens show a kraft envelope with a gold wax seal on a warm beige
cloudy sky, matching Scroll the Bible (`Reference/gift-closed.png`, `Reference/gift-open.png`).
Today the envelope is flat vector art. Replace it with **two generated composites** that already
include the wax seal with our logo pressed into it. The app keeps drawing only what changes at
runtime: the offer text on the card, and the sky behind.

## Deliverables

| Asset | Canvas | Alpha | Content |
|---|---|---|---|
| `envelope-closed.png` | 1200×900 | transparent | Closed envelope, back view, four folds meeting at centre, gold wax seal **with our logo ring embossed**, unrotated (the app rotates it −6.6°), filling ~96% of the width, centred. |
| `envelope-open.png` | **1000×1500 portrait** | transparent | Same envelope open, composed as a tall tower for a portrait phone: a **portrait cream card (3:5) standing high out of the pocket**, its top well above the envelope, so roughly two thirds of the card is visible; a **tall flap** raised straight up behind the card, its peak above the card's top edge; the wax seal on the front pocket **with the logo**; same camera, light and paper as the closed one. The envelope occupies the lower ~45% of the canvas, the card and flap the rest. |
| `gift-clouds.png` | 1179×2556 | opaque | Warm beige sky with soft white cumulus clouds, brighter top-left, no horizon, no objects. Only needed if you want to replace the current procedural sky. |

PNG, sRGB, 8-bit, straight alpha. Sources go in `Artwork/src/gift/`; `Artwork/tools/build.sh`
copies finished layers into the asset catalog. The app draws the text; if the generated logo comes
out soft, the app can overlay its own crisp emboss on the seal (the Phase 4e code path) as a fallback.

## Logo reference
Attach `Artwork/Logo/Variants/logo-transparent.png` (or `Artwork/Logo/mark-black-512.png`) to every
envelope prompt and say the seal emblem is *this exact symbol*. Midjourney: `--cref <logo url> --cw 100`
plus `--sref` the closed render when doing the open one. GPT-image / Gemini image: attach the logo and
the closed render as inputs. Flux Kontext / Ideogram: use the logo as the "image to include".

## Style constants (paste into every prompt)
Kraft/manila envelope paper `#E8D9B4` lit to `#F3E7C9`, fine fibre texture, softly worn edges, no
printing, no address, no stamp. Card cream `#F5EFE1`, smooth, faint grain, rounded corners.
Wax antique gold `#C9A45C`, highlights `#E2C27A`, shadows `#8C6A2E`, glossy, hand-pressed, irregular
scalloped rim, emblem pressed in as a clean relief. Single soft key light from the top-left, gentle
contact shadow. Straight-on camera with a subtle 8° top-down tilt, 85 mm look, no perspective
distortion. Isolated on a plain flat background (for cut-out). Nothing else in frame.

## Prompts (generate ≥ 2048 px on the long side; closed 4:3 landscape, open 2:3 portrait)

### 1. Closed envelope with sealed logo
```
Photoreal product render of a single closed kraft paper envelope seen from the back, four
triangular folds meeting at the centre under a round antique gold wax seal, the seal hand-pressed
with an irregular scalloped rim and this exact ornamental ring symbol embossed cleanly in its
centre [reference image attached], manila paper #E8D9B4 with fine fibre texture and softly worn
edges, no writing, no stamp, straight-on camera with a subtle 8° top-down tilt, one soft key light
from the top-left, glossy wax highlights, gentle contact shadow, isolated on a plain flat neutral
background, centred, filling the frame, 85mm lens, high detail
```
Negative: `text, letters, address, postage stamp, string, ribbon, hands, table, wood, extra
envelopes, crown, cross, star, monogram, harsh shadows, vignette, checkerboard, transparency pattern`

The closed envelope stays landscape 4:3; it is a small element on the portrait screen and the app
tilts it. Ask for a flat solid white background here too.

### 2. Open envelope with card and sealed logo (portrait, 2:3)
```
Vertical portrait composition, aspect ratio 2:3. The same kraft paper envelope [closed render
attached as style reference], now open and seen from the front, arranged as a tall stack: a blank
cream #F5EFE1 card in PORTRAIT orientation (taller than wide, about 3:5, rounded corners) standing
upright inside the pocket and rising far above the envelope so two thirds of the card is visible
above the pocket; behind the card the top flap is raised straight up as a tall narrow triangle whose
peak is higher than the top of the card; the envelope itself sits in the lower half of the frame
with its front pocket intact; the same round antique gold wax seal with this exact ornamental ring
symbol embossed [logo attached] sits on the front pocket where the folds meet; manila paper
#E8D9B4 with fine fibre texture, no writing anywhere, straight-on camera with a subtle 8° top-down
tilt, soft key light from the top-left, gentle contact shadow, isolated on a flat solid pure white
background, centred, 85mm lens, high detail
```
Negative: same as above plus `landscape card, wide card, card lying flat, short flap, writing on
the card, printed card, percentage, numbers, checkerboard, transparency pattern`

Set the tool's aspect ratio to 2:3 (Midjourney `--ar 2:3`; GPT-image / Gemini: portrait 1024×1536).
Ask for a **flat solid white (or pure green) background**, never "transparent": models paint a fake
checkerboard instead of writing alpha, which is what happened in the first render. I key the flat
colour out.

Reference proportions from `Reference/gift-open.png` (393 pt wide screen): envelope ≈ 340 pt wide,
card ≈ 249 × 417 pt (its top ≈ 170 pt above the envelope's top edge), flap peak ≈ 60 pt above the
card top, seal ≈ 96 pt across, centred on the pocket.

### 3. Cloud sky (optional)
```
Soft warm beige sky filled with gentle white cumulus clouds, pale sand-coloured gradient from
#E7E0CD at the top to #D5CCB2 at the bottom, clouds brighter top-left with warm grey undersides,
calm and dreamy, no horizon, no ground, no sun, no objects, portrait 9:19.5, matte, fine film grain
```
Negative: `horizon, sun, birds, rays, blue, saturated, text, watermark`

## What I do when they land
1. Key out the flat background and pad: closed → 1200×900 landscape, unrotated at ~96% width; open → 1000×1500 portrait with the flap peak ≤ 40 px from the top and the envelope bottom ≥ 40 px from the bottom.
2. Switch the gift screen to the flat composites (skip the code-drawn seal and card image, keep the text overlay and the card's text rect from `PaywallMetrics.openEnvelopeGeometry`), re-measure the seal centre and card rect from the new art.
3. `Tools/verify.sh --snap gift-closed gift-open`, look at the diffs, record RMSE and the accepted deviations in `Reference/scores.md`.

Send the PNGs (plus tool and seed) in chat or drop them in `Artwork/src/gift/`.
