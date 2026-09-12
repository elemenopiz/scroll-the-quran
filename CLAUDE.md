# Scroll the Quran

Native SwiftUI iOS app: a feature-for-feature, pixel-close clone of "Scroll the Bible" with Quran content. **English translation is the primary text; the Arabic Uthmani text is shown as a muted, smaller design layer** (never transliteration). Reference screenshots of the original are in `Reference/` (see `Reference/manifest.json` for screen ids, appearance, routes, and RMSE thresholds). The approved build plan is `~/.claude/plans/we-are-cloning-the-deep-boot.md`; task briefs live in `docs/tasks/`.

## Golden rules
1. **Never edit `*.xcodeproj` / `project.pbxproj`.** The project is generated: edit `project.yml`, then run `xcodegen generate`. A hook blocks pbxproj edits.
2. **All UI and logic lives in `Packages/ScrollKit`** (one local SwiftPM package, 12 targets). `App/` is a thin shell and is frozen after Phase 1, as are `Package.swift` and `project.yml`.
3. **Add files by dropping them into the right folder.** Sources are folder-globbed; `Content/` is a folder reference. No project edits needed.
4. **`Content/` JSON is generated.** Edit the generator in `Tools/content-gen/`, not the output (fixtures in `Content/study/` for surah 1 and 112 are the exception until real content lands).
5. **Arabic treatment ("muted Arabic")**: every verse surface (reader page, Deep Study quote box, share card, widget — **not the Discover card**, by the owner's decision on 2026-09-12: the card shows English only and the Arabic appears on tapping Deep study) shows the Arabic Uthmani line **above** the English, centered, right-to-left, in the bundled Quran font (`Typography.arabicAccent(size)`), at ~55–60% of the English point size, colored `Tokens.textTertiary` (≈35–40% opacity of the primary text). It is decorative context, not the reading text: no tap targets, no line-limit truncation warnings, excluded from VoiceOver by default (`accessibilityHidden(true)`) with the English carrying the label. **Never transliterate**: where a study section names an Arabic term, show the Arabic script (muted style, inline) followed by the English gloss.
6. **Stay inside your task's owned directories** (listed in your brief). Anything out of scope becomes a note in your report, not an edit.
7. **Design tokens only.** Colors, radii, spacing, tracking, and fonts come from `DesignSystem` (`Tokens.swift`, `Typography.*`). Never `.font(.system(...))` or literal hex in feature code.
8. **Modern SwiftUI only:** iOS 17+, `@Observable` (never `ObservableObject`), `NavigationStack`, `@MainActor` view models, Swift Testing (`import Testing`) for unit tests. Every tappable element gets an `accessibilityIdentifier`.
9. **No network calls in the app.** Everything is bundled.

## Commands
```bash
xcodegen generate                       # after editing project.yml
Tools/verify.sh                         # xcodegen → swift build/test (host) → xcodebuild sim build. THE gate.
Tools/verify.sh --ui                    # + XCUITests (layout specs, flows)
Tools/verify.sh --snap reader-dark …    # + capture screens by id and compare against Reference/
cd Packages/ScrollKit && swift test --filter QuranDataTests
Tools/snapshot/compare.sh <screen-id>   # prints RMSE and writes .build/snapshots/<id>-diff.png
```
Simulator: iPhone 17 Pro, iOS 26. Prefer the desktop app's iOS Simulator tools (`build`, then `control` launch/screenshot/tap); fallback `xcrun simctl`. Build output through `xcbeautify`.

## Verification before claiming done
- Run `Tools/verify.sh` (plus `--ui`/`--snap` per your brief) and paste the tail of its output in your report.
- For every screen you touched: capture, compare, look at the diff PNG next to the reference, iterate up to 5 rounds, and **report the RMSE number**. Do not stop at "looks close".
- Unit tests for any logic (paginator, streaks, feed determinism, parsers) before the UI that uses them.

## Architecture
- `RootView` state machine: onboarding → paywall → gift (if paywall closed) → `TabRoot` (Community, Discover, Home, The Quran).
- Stores injected via `.environment`: `TranslationStore`, `StudyStore`, `UserStore` (App Group JSON), `EntitlementStore` (StoreKit 2). `Router` protocol in `AppShell` handles tab selection and deep links (`scrollthequran://verse/2/255`).
- Keys: verse `"2:255"`, passage `"94:5-6"`; global index = `surah.startIndex + ayah - 1` (6,236 verses).
- Reader pages per **surah** (never the whole Quran): `ScrollView + LazyVStack + .scrollTargetBehavior(ReaderPagingBehavior()) + .scrollPosition(id:) + .containerRelativeFrame`. `ReaderPagingBehavior` rounds every target onto the absolute page grid (k × container height); stock `.paging` snaps relative to the current offset and cannot hold a programmatic jump on a boundary (Phase 4j). Every page change goes through `ReaderModel.move(to:)`. Long ayat are split by `VersePaginator` into continuation pages.
- Study JSON per surah shard (`Content/study/surah_NNN.json`), sections in fixed order: meaning, historicalContext, keyTerms, lifeInProphetsTime, didYouKnow, theologicalSignificance, crossReferences, applyIt, exploreFurther.
- Arabic text: `Content/quran/arabic-uthmani.json` (Tanzil Uthmani, CC BY, attribute Tanzil) via `TranslationStore.arabic(for:)`.
- Basmala rule: Tanzil's Uthmani text (kept verbatim per its terms) prefixes ayah 1 of every surah except 1 and 9 with the Bismillah (a fixed 39-char prefix). Never show that prefix inside the verse-1 line; strip it at render time (`ArabicText.stripBasmala`) and show the Bismillah as the muted line on the surah's page 0.
- Attribution: `Tools/content-gen/ATTRIBUTION.md` is the licence ledger (Tanzil CC BY, Itani CC BY-ND, QuranEnc terms for Saheeh/Ruwwad, Pickthall PD, KFGQPC no-modify EULA so the Hafs font must stay unsubsetted).
- Translations: default `itani` (ClearQuran, CC BY-ND, attribute "Translation by Talal Itani, ClearQuran.com"); alternates `saheeh`, `ruwwad`, `pickthall`. Copyright strings shown verbatim in the Translation sheet.

## Screen ids
`onboarding-hook, onboarding-signin, onboarding-slide1..4, onboarding-reviews, paywall-trial, paywall-plans, gift-closed, gift-open, community, discover, deepstudy(#section), reader, translation-sheet, notes-sheet, home(#scrolled)`. Launch argument `--screenshot <id>` routes straight there with fixture data and `SCROLL_FIXED_DATE=2026-09-14`.

## Content pipeline
`Tools/content-gen/` (Node 24, `@anthropic-ai/sdk`): ingest → segment → build-requests → submit-batch → poll → validate → assemble → judge. Study `keyTerms` carry `{ arabic, gloss, note }` (Arabic script, no transliteration field). Always run with `--dry-run` first to see token/$ estimates. Never commit `Tools/content-gen/work/`. Load the `claude-api` skill before touching these scripts.

## Workflow
- Orchestrator (Fable 5.1) writes briefs and gates merges; implementers are Opus agents in worktrees on `phaseN/<task>` branches. Merge order and ownership are in the plan.
- Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
