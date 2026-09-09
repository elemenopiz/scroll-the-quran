# Common rules for every Phase ≥ 2 task

- Work ONLY in your assigned worktree/branch. Do not touch `Package.swift`, `project.yml`, `App/`, `.claude/`, or `Reference/*.png` (frozen after Phase 1). Stay inside your "Owns" list.
- Read `CLAUDE.md`, `Reference/manifest.json`, `docs/tasks/_common.md`, your brief, and the matching plan section in `~/.claude/plans/we-are-cloning-the-deep-boot.md`.
- Build/test gate: `Tools/verify.sh` (add `--ui` / `--snap <ids>` as your brief says). Simulator: booted iPhone 17 (402x874 pt); reference PNGs are 393x852 pt and `compare.sh` normalizes.
- Visual loop: for each screen id you own: build → install+launch with `--screenshot <id>` → `Tools/snapshot/capture.sh <id>` → `compare.sh <id>` → open the diff PNG, compare against `Reference/<file>` → fix → repeat ≤ 5 rounds. Report the final RMSE per screen. "Looks close" is not a result.
- Logic first, TDD (Swift Testing). Every tappable view gets `accessibilityIdentifier` (`<screen>.<element>` naming, e.g. `reader.translationPill`).
- Tokens only (`Tokens.*`, `Typography.*`); no literal colors/fonts in feature code.
- Arabic layer: every verse surface shows the muted Arabic line above the English per CLAUDE.md rule 5 (`Typography.arabicAccent`, `Tokens.textTertiary`, RTL, VoiceOver-hidden). Never transliterate.
- Commit per logical step with trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Do not merge to main.
- Report: files touched, verify output tail, test counts, RMSE per screen, unmet DoD items with reasons, out-of-scope notes.
