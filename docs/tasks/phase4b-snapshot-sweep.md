# Phase 4b — Full snapshot sweep + polish
Owns: any feature package for visual fixes (list every file you touch), `Reference/scores.md`, `Tools/snapshot/thresholds.json`. Simulator: ONLY `ScrollSim-3e`.
Prereq: 3e + 4a merged (every `--screenshot` id resolves in the real app).
Deliver: run `Tools/verify.sh --snap all` for every id in `Reference/manifest.json` in BOTH appearances (`xcrun simctl ui <udid> appearance dark|light`), inspect every diff PNG with Read, fix the highest-impact visual deltas (spacing, weights, tints, radii, icon choices such as outline vs filled tab icons) up to 5 rounds per screen, and write `Reference/scores.md` (table: id, appearance, RMSE, threshold, pass/fail, notes). Light-mode contrast pass for cards on `#FAFAFC` (raise card contrast via a subtle border or slightly darker card token, keeping measured dark values untouched). Dynamic Type sanity at XL on reader/discover/deep study (no clipped text; verse text may cap).
DoD: every screen below its threshold or an explicit accepted-deviation note; `Tools/verify.sh --ui --snap all` PASS; scores.md committed.

Known polish items from earlier reviews:
- Multi-ayah passage quotes are joined with a bare space ("…call for help Guide us…"): join ayat with a terminal mark when the source lacks one, or insert a small muted ayah-number separator (e.g. ⟨6⟩) between ayat in `VerseText`/`PassagePresentation`.
- Discover card: the Arabic accent line renders very small on long passages; consider a floor of 13 pt and up to 3 lines before the English.
- Tab bar: unselected tab icons should be outline variants (reference) not auto-filled.
- `TintedSectionBox` needs a header slot for the per-section copy button (FeatureDiscover composes locally today).
- Onboarding slides use placeholder mockup art: unfreeze Package.swift to give `FeatureOnboarding` a `resources: [.process("Resources")]` rule, render `reader`, `discover`, `plans-sheet`, `verse-search` via `--screenshot` into the PhoneFrame window (1119×2496 at +30+30) with `Tools/snapshot/render-mockups.sh`, and swap `MockupArt` blocks for the PNGs.
- Sign-in sheet: add a second detent or keyboard avoidance so the email field isn't covered.
