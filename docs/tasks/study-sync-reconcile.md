# StudyContent ↔ pipeline reconciliation
Owns: `Packages/ScrollKit/Sources/StudyContent/**`, `Tests/StudyContentTests/**`, `Content/study/**`, `Content/discover.json`, `Content/themes.json`, `Tools/content-gen/sync-study-content.mjs`.

Problem: `node Tools/content-gen/sync-study-content.mjs` copies the real pipeline output into `Content/`, after which 25 StudyContent assertions fail. Root causes to fix on the Swift side (the pipeline output is the source of truth and must not change):
1. `out/study/passages.json` maps ALL 6,236 ayat to their unit keys (3,293 units) even though only ~40 units have studies so far. `StudyStore.hasStudy(for:)` must mean "a study exists", i.e. consult a per-shard key index (load the shard lazily, or maintain a lightweight index built once from shard files) — not just the passages map. Keep `unitKey(for:)` as the passages-only lookup for the reader.
2. `out/discover.json` shape is `{seed, promptVersion, generatedAt, count, items:[{key, surah, start, end, themeId, title}]}`; `out/themes.json` is `{…, themes:[{id,title,blurb,refs}]}` or similar — decode exactly what the files contain (read them).
3. Shard shape `{surah, promptVersion, generatedAt, studies:[…]}`.
4. Phase-1 hand fixtures `Content/study/surah_103.json` and `surah_112.json` use an obsolete shape and non-existent themeIds; delete them (surah 112 and 103 will be authored by the pipeline). Update tests to use the synced real content plus small in-memory fixtures, not hand JSON.
5. Make `sync-study-content.mjs` also delete stale fixture-only shards when `--prune` is passed, and run it with `--prune`.
DoD: `node Tools/content-gen/sync-study-content.mjs --prune` then `swift test --filter StudyContentTests` all green (≥ 35 tests), `Tools/verify.sh` PASS, `git status` clean after a second sync run (idempotent).
