# Assets worth generating (owner's offer, 2026-09-12)

Ranked by how much they change what a reader sees. Same style constants as `gift-assets-prompts.md`: one soft key light, no text in the image, no people's faces, no real organisations, flat solid background if a cut-out is needed. Deliver PNG or JPEG, sRGB, sizes below; drop them in `Artwork/src/<folder>/` and I wire them.

## 1. Reading-plan covers (highest impact)
Where: Home "Today's Reading" card, the plans sheet, plan detail. Today: 8 procedural illustrations (`Artwork/PlanCovers/`). The reference app uses stock photographs, and these covers are the largest remaining snapshot deviation (`plans-sheet` 0.19, `plan-detail` 0.14).
Spec: **1200×800**, landscape, photoreal or painterly, muted warm palette that sits under a dark scrim with white text (avoid busy centres; keep the subject in the lower-left or right third), no text, no calligraphy that spells a real word.

| slug | subject | mood |
|---|---|---|
| `mushaf-page` | open mushaf on a wooden rehal, shallow depth of field | quiet study |
| `prayer-beads` | wooden misbaha on linen | contemplative |
| `geometric-tile` | zellige tile detail, indigo and cream | timeless |
| `dawn-light` | dawn over a minaret skyline, mist | new beginning |
| `lantern` | brass Ramadan lantern, warm glow, dark room | night |
| `ink-wash` | ink and reed pen on parchment, no legible words | learning |
| `desert-dune` | dune ridge at golden hour | patience |
| `olive-branch` | olive branch on stone, soft shadow | mercy |

Plus the wish-list the reading-plans agent appends below (new plans: Sunnah of reading, prophets, names of God, duas, memorise).

## 2. Charity cards (Community tab)
Where: the three charity vote cards. Today: procedural (water drop, hands, wheat). Spec: **1200×600**, abstract and warm, no logos, no faces, no real organisation, reads under a dark gradient with white titles.
| slug | subject |
|---|---|
| `clean-water` | a single clear water ripple, cool tones |
| `giving-hands` | two open hands cupping light, from above, no face |
| `harvest-wheat` | wheat heads against a low sun |

## 3. Portrait open envelope (still pending from the Codex limit)
`docs/design/gift-assets-prompts.md`, prompt 2 (2:3 portrait, tall card, tall flap, flat white background). The current gift-open screen is assembled from layers and looks right, so this is a nice-to-have.

## 4. Do NOT generate
- The app icon and in-app mark: done from the supplied logo (`Artwork/Logo`).
- The iPhone bezel for the onboarding mockups: built from device geometry in code (Phase 4h). If you want a photographic bezel instead, use Apple's official product bezels from developer.apple.com/design/resources (their licence allows marketing use); do not ask a model to draw an iPhone.
- Sky/clouds: already generated.
- Onboarding slide screenshots: rendered from the real app.

## Reading-plan covers wish-list (appended by the plans task)
_(pending)_
