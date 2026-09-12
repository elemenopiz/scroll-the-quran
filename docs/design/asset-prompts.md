# Asset generation prompts — Scroll the Quran

Every image the app can take from a generator, with a ready-to-paste prompt. Deliver PNG or JPEG, sRGB, at least the size listed; drop files in `Artwork/src/covers/`, `Artwork/src/charity/`, `Artwork/src/gift/` named by slug and I wire them.

## Global style block (paste at the end of every prompt)

```
Photoreal, natural materials, one soft key light from the upper left, gentle falloff into
shadow, restrained palette of warm sand, stone, ink and brass with cool shadows, no text,
no calligraphy that spells a real word, no logos, no people's faces, no hands unless the
prompt asks for them, subject placed off-centre in the lower-left or right third leaving
the upper two thirds calm and low-contrast, matte finish, very fine film grain,
85 mm lens, shallow but not extreme depth of field, no vignette, no watermark
```

Negative block (for tools that take one):

```
text, letters, arabic words, calligraphy, logo, watermark, face, eyes, cartoon, 3D render
look, neon, saturated, high contrast, HDR, busy centre, clutter, borders, frames, vignette
```

Tool settings: Midjourney `--ar 3:2 --style raw --stylize 100` for covers, `--ar 2:1` for charity cards; GPT-image / Gemini image: landscape 1536×1024 for covers (crop to 3:2), 1536×768 for cards; Flux/Ideogram: 1200×800 and 1200×600 directly. Ask for a **flat, evenly lit background** where a cut-out is needed (never "transparent": models paint a fake checkerboard).

Why "subject off-centre, upper two thirds calm": every cover sits under a dark gradient scrim with a white title over the top third and a white subtitle under it. A busy or bright top ruins the title. Test any candidate by darkening its top 40 % by 60 % and imagining white text on it.

---

## A. Reading-plan covers — 1200×800 (3:2), landscape

Where they appear: Home "Today's Reading" card (cropped to ~3:1), the plans sheet grid (3:2 tiles), plan detail header (full-bleed 3:2). The first 8 replace procedural art; the next 10 free up covers that three plans currently share.

### A1 `mushaf-page` — A juz a day
```
An open mushaf resting on a carved wooden rehal, cream paper with faint ruled lines and
no legible words, the near page slightly lifted, warm morning light from the upper left,
the book in the lower-right third, the upper two thirds a soft out-of-focus plaster wall
in warm sand tones
```

### A2 `prayer-beads` — Prayers in the Quran (shared today with A hizb a day)
```
A wooden misbaha of dark olive-wood beads lying in a loose curve on undyed linen, the
tassel resting at the lower-left, soft window light, the beads sharp and the linen fading
to a calm neutral field in the upper two thirds
```

### A3 `geometric-tile` — The verses of refuge, Al-Baqarah at night
```
A close detail of hand-cut zellige tilework, eight-point star pattern in deep indigo,
cream and a little sand, slight glaze imperfections, raking light from the upper left
catching the edges, the pattern sharpest in the lower-right and softening into shadow
toward the top
```

### A4 `dawn-light` — Mercy (shared with Your first week, Morning and evening)
```
Dawn over a low skyline with a single minaret in silhouette at the lower-right, thin mist
over rooftops, the sky a quiet gradient from grey-blue to pale apricot, no sun disc, no
birds, the upper half almost empty
```

### A5 `lantern` — Juz Amma (shared with Al-Mulk, A Ramadan reading)
```
A brass Ramadan lantern with pierced star cut-outs standing on a stone ledge in a dark
room, lit from within with a warm amber glow, placed in the lower-left third, the glow
fading into near-black in the upper two thirds, no flame visible, no other objects
```

### A6 `ink-wash` — Al-Kahf on Fridays, Surah Yusuf
```
A reed pen resting across a sheet of parchment with a dried wash of black ink that reads
as texture, not letters, a small brass inkwell at the lower-right, soft daylight from the
upper left, the parchment fading to a warm cream field above
```

### A7 `desert-dune` — Patience, The prophets
```
A single sand dune ridge at golden hour, the crest running from the lower-left toward the
right, wind ripples in sharp relief, long soft shadow on the lee side, a clear pale sky
taking the upper two thirds, no footprints, no plants
```

### A8 `olive-branch` — Gratitude, Turning back
```
A fresh olive branch with a few grey-green leaves lying on a pale limestone slab, one
soft shadow from the upper left, the branch in the lower-right third, the stone's grain
visible but calm across the rest of the frame
```

### A9 `night-window` — Al-Mulk before sleep, Al-Baqarah at night
```
A closed wooden shutter at night seen from inside, one small oil lamp on the sill beside a
closed book, the lamp's warm pool of light on the wood in the lower-left, the room falling
to deep blue-black above, no stars visible, no faces
```

### A10 `crescent-sky` — A Ramadan reading
```
A thin new crescent moon high in a deep blue evening sky, the crescent small and placed in
the upper-right third, flat rooftops and a single dome in silhouette along the bottom
edge, no lanterns, no text, the sky smooth and almost empty
```
(Exception to the rule: the subject sits high here on purpose; the scrim title will sit over the empty left side. Keep the crescent small.)

### A11 `morning-doorway` — Morning and evening
```
Daylight falling through an open wooden doorway onto a worn stone floor, the doorway at
the right edge, the bright wedge of light across the lower half, the interior wall in
soft shadow taking the upper-left, no people, no objects
```

### A12 `caravan-road` — The prophets
```
A worn track between rock outcrops at dusk, a few old footprints and camel prints in the
sand in the lower-left, the track curving away toward a pale horizon, cool shadow on the
rocks, no figures, no animals in frame
```

### A13 `wheat-and-well` — Surah Yusuf
```
Two bound sheaves of wheat leaning against the stone head of an old well, late afternoon
light from the upper left, the sheaves in the lower-right third, dry packed earth and a
plain warm sky above, no rope, no bucket, no people
```

### A14 `open-hands` — Prayers in the Quran
```
Two open palms held together in a gentle cup, photographed from directly above in soft
side light, the hands in the lower-left third, plain dark cloth beneath, wrists cropped by
the frame edge, no face, no jewellery, no other objects
```

### A15 `rain-on-stone` — Turning back (repentance)
```
The first drops of rain darkening dry sandstone paving, a few bright fresh droplets in
sharp focus in the lower-right, the rest of the stone still pale and dry, overcast even
light, no puddles, no people, no plants
```

### A16 `writing-board` — Forty short surahs (memorise)
```
A wooden Quranic writing board, worn and pale, with faint washed-out ink traces that read
only as texture, propped at an angle in the lower-left, a small pot of ink beside it,
soft window light, a plain plaster wall behind
```

### A17 `stacked-volumes` — A hizb a day
```
Thirty thin cloth-bound volumes in muted greens, browns and dark reds stacked on a wooden
shelf, spines plain with no lettering, warm lamplight from the upper left, the stack in
the lower-right third, the wall above in shadow
```

### A18 `first-page` — Your first week
```
A mushaf opened at its very first spread, ornamental frame rendered as soft shapes with no
legible words, morning light across the gutter, the book in the lower-right third, cream
pages and a calm out-of-focus room above
```

### A19 `friday-light` (nice to have) — Al-Kahf on Fridays
```
Late-afternoon light falling in long stripes across an empty carpeted prayer hall, the
light entering from the right, columns in soft shadow, the carpet pattern subdued, no
people, no text
```

### A20 `lamp-and-cup` (nice to have) — By theme shelf
```
A low brass lamp and a small ceramic cup on a wooden tray, steam barely visible, the tray
in the lower-left, warm lamplight fading to a dark plain wall above, no hands, no text
```

---

## B. Charity cards — 1200×600 (2:1), landscape

Where they appear: the Community tab's three vote cards under a dark gradient with a white title and vote count. Abstract and warm, no real organisation, no logos, no faces.

### B1 `clean-water`
```
A single clear ripple spreading across still water photographed from slightly above, cool
blue-grey tones, the ripple's centre in the lower-right third, the surface fading to a
calm gradient toward the top, a few bright specular highlights, no drops mid-air, no
objects
```

### B2 `giving-hands`
```
Two open hands passing a small round loaf from one to the other, photographed from above
in warm side light, forearms cropped by the frame edges, hands in the lower-left third,
plain dark cloth beneath, no faces, no jewellery
```

### B3 `harvest-wheat`
```
A field of ripe wheat heads against a low golden sun, the heads sharp and back-lit in the
lower-left third, the rest dissolving into a warm haze, no sun disc, no machinery, no
people
```

---

## C. Gift envelope (pending from the Codex limit)

Full prompts and layer specs in `docs/design/gift-assets-prompts.md`. Only the portrait open envelope (prompt 2, 2:3) is still wanted; the current screen is assembled from your first-pass layers and looks right, so this is a nice-to-have.

---

## D. Do not generate
- App icon and in-app mark (built from the supplied logo).
- iPhone bezel (built from device geometry in Phase 4h; Apple's official bezels if you want a photographic one).
- Sky and clouds (done).
- Onboarding slide screenshots (rendered from the real app).
- Any image containing Arabic words or Quranic text: the app renders those itself from the Tanzil text so they are always correct.

## Delivery checklist
1. One file per slug, named `<slug>.png` or `.jpg`, at least the listed size, no upscaling artefacts.
2. Generate 3–4 candidates per slug and send only the one where white text would read over the top third.
3. Tell me the tool and seed so a re-roll keeps the family look.
