# Phase 4o — REFLECTION cards in the Discover feed (owner, 2026-09-13)
Worktree: `git worktree add ../scroll-the-quran-4o -b phase4/4o-reflection-card` from `main` **after** `content/reflections` (the `Reflection` model + `Content/reflections.json`) and `phase4/4m-quote-fit` have merged. Simulator: ONLY ScrollSim-3e `783AB01C-1054-4BF6-8A1C-66B6DD9CEEB6`; shut it down when done.
Owns: `Packages/ScrollKit/Sources/FeatureDiscover/{ReflectionCard.swift (new), DiscoverView.swift, DiscoverScreens.swift, DiscoverMetrics.swift (additions only)}`, `Packages/ScrollKit/Sources/StudyContent/DiscoverFeed.swift` (feed item enum), `Packages/ScrollKit/Sources/AppShell/{AppEnvironment.swift,ScreenRegistry.swift,LaunchOptions.swift}` (wiring the store + route `discover-reflection` only), tests in `FeatureDiscoverTests` + `StudyContentTests`, `UITests/DiscoverTests.swift`, `UITests/Specs/discover-reflection.json` (new), `Reference/manifest.json`, `Tools/snapshot/thresholds.json`, `Reference/scores.md`.

## What the original does (owner's screenshot, 402×874 pt; no PNG on disk — geometry measured from it)
A card with exactly the Discover card's frame (same fill, same corner radius, x 16.6…385 pt, top ≈ 124 pt = 14.2 %, bottom ≈ 730 pt = 83.5 % — i.e. `DiscoverCardLayout.cardHeight`, same page placement; the previous card's action row is visible above it at the top of the screen just as with study cards) containing, vertically centred as a group on the card's centre (≈ 427 pt):
- a 73 pt circle, fill `chipBackground` (one step lighter than the card), with a large serif open-quote glyph (“ in the display serif, ≈ 44 pt, `textSecondary`) centred; circle centre ≈ (201, 311) pt;
- 42 pt below it the caps label **REFLECTION** (`CapsLabel`, `textSecondary`, wide tracking), centred;
- 32 pt below, the quote: display serif ≈ 26 pt regular, `textPrimary`, centred, line pitch ≈ 34 pt, up to 6 lines, horizontal padding 40 pt inside the card;
- 28 pt below, the attribution "— Augustine of Hippo": ≈ 17 pt semibold, `textSecondary`, centred, an em dash then a space.
No action row on the card (bookmark/comment/share/check are not shown for reflections in the screenshot). Long quotes (ours are ≤ 45 words) step the serif down to 22 pt before wrapping past 6 lines; never truncate a reflection.

## Feed
- `DiscoverFeed` items become `enum DiscoverFeedItem { case study(DiscoverItem), reflection(Reflection) }` (Identifiable by prefixed id). Interleave deterministically from the same day seed: one reflection after every 4 study cards, starting at position 4 (the first card of the day stays a study card so `discover-dark` is unchanged), reflections drawn without repetition through the day's order.
- Reflections are **free and unmetered**: they do not count toward `DiscoverGate.freeCardsPerDay`, and are never replaced by the paywall card. Deep Study, comments, bookmarks do not apply to them.
- `--discover-index N` still addresses the combined list; add `--screenshot discover-reflection` = the day's first reflection card as card 0 (a launch option that puts a reflection first), so the capture is stable.
- Reflection theme filter: none in v1 (the feed is one stream).

## Tests and captures
Unit: interleaving is deterministic for a seed, the 4:1 ratio holds over a full day's list, no reflection repeats within a day, position 0 is a study card, gate counting ignores reflections. UI: `discover-reflection` layout spec (circle, label, quote, attribution rows) and a paging test that reaches a reflection by swiping 4 times from card 0. Capture `discover-reflection` and Read it against the geometry above; no reference PNG yet (owner to drop `discover-reflection.png` in), so the manifest entry has no threshold and `scores.md` says so. `SCROLL_SIM=… SCROLL_CAPTURE_SETTLE=6 Tools/verify.sh --ui --snap discover-dark` PASS with discover-dark's RMSE unchanged (report before → after).

Merge into main with `--no-ff`, remove the worktree, shut the sim down.
