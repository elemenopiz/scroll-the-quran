# Content tooling — session-agent authoring mode for Deep Study
Context: no Anthropic API key is available, so Deep Study notes are written by Claude Opus agents inside Claude Code sessions instead of the Batch API. The existing pipeline (Tools/content-gen, see README.md) stays the source of truth for prompts, schema, validation, and assembly. Segmentation is now `--min-own-words 24 --max-words 60` (3,293 units; `out/study/passages.json` already regenerated and committed).

Owns: `Tools/content-gen/author.mjs`, `Tools/content-gen/lib/author.mjs`, `Tools/content-gen/test/author.test.mjs`, README section "Authoring mode", `Tools/content-gen/out/study/**` for the units you author, `docs/tasks/content-author.md` (the brief future author agents will follow).

Deliver `node author.mjs <command>`:
- `todo [--only discover|all|surah:N|keys a,b,c] [--limit N]` → prints unit keys that have no `work/cache` record AND no record in the committed `out/study/surah_NNN.json` shards (so waves never redo work), with word counts.
- `prompt <key> [--no-system]` → prints the exact system prompt (prompts/system.md + theme list, same as build-requests) once, then the rendered user turn for that unit (reuse lib/prompt.mjs; do not duplicate templating logic).
- `write <key> <body.json> [--author "opus-session"]` → runs the full validate.mjs rule set on the body (schema, word bounds, Arabic placement, ref bounds, banned phrasing, honorific, themeId, key agreement) and, if clean, writes `work/cache/p1--<model>--<key>.json` in exactly poll-batch's record shape `{key, promptVersion:"p1", model:"claude-opus-5", usage:null, author, body, receivedAt}`; exit non-zero with the validation messages otherwise. Also accepts a directory of `<key>.json` bodies: `write-dir <dir>`.
- `assemble` → thin wrapper over assemble.mjs (all cached) that also prints per-surah counts and the remaining Discover gaps.
- `status` → counts: units total / cached / assembled / discover remaining, per-surah table.
Tests in `test/author.test.mjs` (node --test): todo excludes cached and assembled keys; write rejects an invalid body and accepts a valid one; record shape matches what assemble expects (round-trip through assembleStudy).

Then PROVE the flow by authoring the first 40 units of `todo --only discover` yourself as an Opus author: for each key run `prompt`, write the JSON body following prompts/system.md rigorously (mainstream, classical-tafsir grounded, no rulings, honorific once, Arabic only in keyTerms[].arabic, refs in bounds, second-person applyIt, word bounds from schema x-wordBounds), `write` it, fix any validation errors, then `assemble`, and run `node validate.mjs out/study`. Commit the tool, then the content, with trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

Finally write `docs/tasks/content-author.md`: a self-contained brief for future author agents (how to claim a slice via `todo --only surah:N`, the quality bar with two exemplary bodies you wrote, common validation failures and fixes, the exact commands, commit conventions, and the rule that an agent never edits shards by hand — only through `write`/`assemble`).
DoD: `npm test` green incl. author tests; `node author.mjs status` shows ≥ 40 assembled; `node validate.mjs out/study` exits 0; README updated.
