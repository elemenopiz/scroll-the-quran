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

## Professional-polish checklist (owner's ask, 2026-09-12: "everything inside should look polished/professional")
Beyond RMSE, walk every screen in both appearances and fix or file each of these; record the outcome per screen in `Reference/scores.md` notes:
- **Clearance:** nothing under the Dynamic Island/status bar or behind the home indicator; sheets respect the top detent grabber; toasts never cover tab bar or CTA.
- **Alignment and rhythm:** one horizontal margin per screen family (`Spacing.*`), card paddings identical across Discover/Home/Deep Study, section headers on the same baseline grid, icons optically centred in their pills.
- **Typography hierarchy:** at most three text sizes per screen; tracking from tokens; no orphan single words on titles at the default size; Arabic muted line never wraps to more than 3 lines.
- **Radii and borders:** one radius per component class (`Radius.*`); light-mode cards visibly separated from `#FAFAFC` (hairline or darker token) with dark values untouched.
- **Iconography:** unselected tab icons outline, selected filled; SF Symbol weights match the adjacent text weight; no mixed icon families in one row.
- **States:** empty states for Library/Notes/Plans with copy and a CTA; loading never flashes blank; disabled buttons look disabled; pressed states on every pill/CTA.
- **Copy:** no placeholder strings ("Placeholder review", lorem, TODO) reach the screen; sentence case per the reference; consistent product names ("Deep Study", "The Quran").
- **Motion:** paging snaps without overshoot; sheet and toast animations use the same duration/curve; no layout jumps when the Arabic line loads.
- **Dynamic Type at XL:** no clipped or overlapping text on reader, Discover, Deep Study, Home (verse text may cap).
- **Brand:** logo mark sizes/clearance as set by Phase 4e; do not change them here, but flag any screen where the mark looks out of place.

## Also fix (from docs/qa/brand-review.md, Phase 4e walk)
Items 1–8 in that file: Deep Study and Home scroll under the status bar unmasked; onboarding-reviews Continue pill has no scrim; onboarding-signin light hairlines; slide mockups still wireframes; Today's Reading cover blank + panel bleed behind tab items; notes-sheet captures without keyboard; OnboardingMetricsTests order dependency (register fonts in a suite setup). Item 9 (widget target placeholder icon) needs a project.yml edit: report it, do not do it.
