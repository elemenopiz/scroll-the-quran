# Phase 2g — Original artwork & app icon (no Swift)
Owns: `Artwork/**` (source SVG/PNG + a README of what each asset is for). The orchestrator wires them into asset catalogs later.
Constraints: everything original (no copying Scroll the Bible's crown, envelope, photos, or copy). Generate with ImageMagick 7 (`magick`), Python (Pillow/cairosvg if installable via `pip3 --user`), or hand-written SVG. Reference the look in `Reference/*.png` for composition only.

Deliver (PNG @1x/2x/3x where used in-app, plus SVG source):
1. **App icon**: 1024×1024 PNG, no alpha, and the SVG. Concept: a minimal geometric mark evoking a mushaf page / crescent / eight-point star in the app's black-and-white language (works on light and dark, like the crown-of-thorns mark does). Also produce a 180×180 preview and a monochrome variant for the reader's centered "logo card" (the reference shows a white line-art mark inside a rounded dark square).
2. **Logo card mark**: 512×512 PNG white line-art on transparent, and black variant.
3. **Gift envelope**: closed envelope with a gold wax seal bearing the mark (≈1200×900 PNG, transparent), and an "opened" variant with the flap up and an inner card slot; plus a soft cloud background (1179×2556) in warm beige (#E8E1CF-ish base with white cloud blobs, matching `Reference/gift-closed.png` tone).
4. **Paywall/trial timeline icons**: lock, bell, check as 64×64 white glyph PNGs (or note that SF Symbols `lock.fill`, `bell.fill`, `checkmark` cover it and skip).
5. **Reading plan covers** (8, 1200×800 each, no text baked in): abstract/photographic-feel compositions — mushaf page macro, prayer beads, geometric tile, dawn light, lantern, calligraphy-free ink wash, desert dune, olive branch. Can be generated procedurally (gradients, noise, geometric patterns via ImageMagick) — they must look premium, not clip-art. Provide dark overlays so white titles read.
6. **Charity card imagery** (3, 1200×600): abstract "giving" compositions (hands/wheat/water motifs as silhouettes or patterns), no real logos.
7. **Onboarding phone-frame**: a 1179×2556 transparent PNG of an iPhone frame (bezel + dynamic island) to overlay our own screenshots, matching the frame in `Reference/onboarding-slide1-feed.png`.
8. `Artwork/README.md` with a table: file, purpose, size, how generated, licence (all CC0/original).
DoD: every file listed exists at the stated sizes (`magick identify`); `Artwork/README.md` complete; total under 25 MB; a contact sheet `Artwork/contact-sheet.png` (`magick montage`) so the orchestrator can review at a glance.
