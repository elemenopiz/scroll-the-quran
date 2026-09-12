# Gift screen artwork — image-generation brief

The gift ("one-time offer") screens are composited from five bitmap layers plus a wax seal that the
app draws in code so it can carry our logo. Today those layers are flat vector stand-ins
(`Artwork/tools/*.py`). Replace them with generated images that match the Scroll the Bible
reference (`Reference/gift-closed.png`, `Reference/gift-open.png`): a photoreal kraft envelope on
a warm beige cloudy sky.

## What the app expects (drop-in, no code change)

| Asset (imageset in `App/Assets.xcassets`) | Canvas | Alpha | Content |
|---|---|---|---|
| `EnvelopeClosed` → `envelope-closed-1200x900.png` | 1200×900 | transparent | Closed envelope, back view (four folds meeting at the centre), **no seal**, unrotated, filling ~96% of the width, centred. The app rotates it −6.6° and draws the seal. |
| `EnvelopeOpenBack` → `envelope-open-back-1200x900.png` | 1200×900 | transparent | Open envelope **rear panel + raised flap**, flap peak near the top edge, inside of the pocket visible. No card, no seal. |
| `EnvelopeOpenFront` → `envelope-open-front-1200x900.png` | 1200×900 | transparent | Only the **front pocket** (lower half) of the same envelope, same camera, same lighting, cut from the same render as the back layer so the edges register. |
| `EnvelopeCard` → `envelope-card-1200x900.png` | 1200×900 | transparent | Cream card stock (portrait, rounded 24 px corners, subtle paper grain, faint drop shadow), blank. The app prints "One Time Offer / 33% OFF / +3 day trial" on it. |
| `GiftClouds` → `gift-clouds-1179x2556.png` | 1179×2556 | opaque | Warm beige sky with soft white cumulus clouds, brighter top-left, no horizon, no objects. |
| Wax seal (drawn in code, optional bitmap `WaxSealBlank`) | 600×600 | transparent | Blank gold wax seal disc, irregular scalloped edge, **no emblem** — the app embosses the logo ring into it. |

Deliver PNG, sRGB, 8-bit, straight (non-premultiplied) alpha. Put sources in `Artwork/src/gift/`
and the finished layers in `Artwork/Gift/`; `Artwork/tools/build.sh` copies them into the asset
catalog.

## Style constants (use in every prompt)

- Envelope paper: kraft/manila, colour ≈ `#E8D9B4` lit to `#F3E7C9`, soft fibre texture, slightly worn edges, no printing, no address, no stamp.
- Card: cream `#F5EFE1`, smooth, faint grain.
- Wax: antique gold `#C9A45C`, highlights `#E2C27A`, shadows `#8C6A2E`, glossy, hand-pressed look.
- Sky: beige `#E7E0CD` → `#D5CCB2` gradient, clouds soft white with warm grey undersides.
- Light: single soft key from top-left, gentle contact shadow under the envelope, no hard specular.
- Camera: straight-on, very slight top-down tilt (≈ 8°), 85 mm look, no perspective distortion.
- Nothing else in frame. No text, no hands, no table.

## Prompts

Generate square or 4:3, at least 2048 px on the long side, then cut out and pad (see post-processing).

### 1. Closed envelope (for `EnvelopeClosed`)
```
Photoreal product render of a single closed kraft paper envelope seen from the back, the four
triangular folds meeting at the centre, no wax seal, no writing, no stamp, manila colour #E8D9B4
with fine paper fibre texture and slightly softened edges, straight-on camera with a subtle 8°
top-down tilt, one soft key light from the top-left, gentle contact shadow, isolated on a plain
neutral background, centred, filling the frame, 85mm lens, high detail, no perspective distortion
```
Negative: `text, letters, stamp, address, hands, table, wood, wax seal, string, ribbon, extra envelopes, harsh shadows, vignette`

### 2. Open envelope, empty (source for `EnvelopeOpenBack` and `EnvelopeOpenFront`)
```
Photoreal product render of the same kraft paper envelope now open and empty, seen from the front,
the top flap raised straight up to a sharp peak, the inside of the pocket visible and slightly
darker, front pocket intact, no card inside, no wax seal, no writing, manila colour #E8D9B4 with
fine paper texture, straight-on camera with a subtle 8° top-down tilt, soft key light from the
top-left, gentle contact shadow, isolated on a plain neutral background, centred, 85mm lens
```
Negative: same as above plus `card, letter, paper inside, seal`.

Ask for the same seed/reference as prompt 1 (Midjourney: `--cref` on the closed render; DALL·E/GPT-image: attach the closed render and say "same envelope"). Register the two layers by cutting the front pocket out of this one image rather than generating it separately.

### 3. Blank wax seal (for the code-drawn seal, optional bitmap)
```
Photoreal top-down render of a single blank round wax seal in antique gold #C9A45C, hand-pressed
with an irregular scalloped rim and a smooth flat centre with no emblem, glossy wax highlights
#E2C27A and shadows #8C6A2E, soft key light from the top-left, isolated on a transparent
background, centred, filling the frame, high detail
```
Negative: `emblem, crest, letter, monogram, crown, star, text, envelope, paper, ribbon`

Do **not** ask the generator to draw our logo into the wax; it will not reproduce the ring
faithfully. The app embosses `LogoMarkBlack` into the seal centre (Phase 4e).

### 4. Cloud sky (for `GiftClouds`)
```
Soft warm beige sky filled with gentle white cumulus clouds, pale sand-coloured gradient from
#E7E0CD at the top to #D5CCB2 at the bottom, clouds brighter top-left with warm grey undersides,
dreamy and calm, no horizon, no ground, no sun, no objects, portrait 9:19.5, matte, fine film grain
```
Negative: `horizon, sun, birds, rays, sharp edges, blue, saturated, text, watermark`

### 5. Blank card (for `EnvelopeCard`)
```
Photoreal top-down render of a blank cream #F5EFE1 card in portrait orientation with softly
rounded corners, smooth uncoated paper with a faint grain, very light drop shadow, isolated on a
transparent background, centred, no text
```

## Post-processing (I do this once the images land)

1. Cut out on transparency (`magick … -fuzz 2% -transparent` for flat backgrounds, or a matting tool for the cloud-edge cases); keep straight alpha.
2. Pad to the canvases above with `magick <src> -resize 1152x864 -background none -gravity center -extent 1200x900`. Closed envelope: unrotated, fills ~96% width. Open envelope: flap peak ≤ 40 px from the top edge; the front pocket is masked from the same image (lower ~48%) into its own layer.
3. Match the app's geometry (`PaywallMetrics.closedEnvelope` 235×153 pt, `openEnvelopeGeometry` with the card rect 249×417 pt at (72,143)); adjust the pad if the flap or pocket lands off the seal centre.
4. Compare `gift-closed` / `gift-open` against `Reference/` with `Tools/verify.sh --snap gift-closed gift-open` and record RMSE in `Reference/scores.md`.

## Where to send them
Drop the finished PNGs in `Artwork/src/gift/` (or share them in chat) and say which tool and seed you used, so a regen keeps the same envelope.
