# Content — Simpler wording for Deep Study, plus an "Explain easier" line (owner, 2026-09-13)
Owner: "the meaning section and other sections within deep study have decently complex/complicated wording." Measured on the 3,293 shipped units (Flesch–Kincaid grade, median / p90): meaning 9.2 / 11.4, historicalContext 11.0 / 13.2, theologicalSignificance 11.0 / 13.1, lifeInProphetsTime 9.9 / 12.1, didYouKnow 12.0 / 14.6, applyIt 7.0 / 9.1. Frequent long words: commentators, intercession, accountability, hypothetical, intermediaries, lexicographers, substitution, grammatically.

Target after the rewrite: every prose section at **grade ≤ 8.5** (didYouKnow / historicalContext ≤ 9.5), sentences ≤ 20 words on average, and a new **`explainEasier`** field (25–50 words, grade ≤ 6: "what this passage is saying, as you would tell a 12-year-old") that the reader's verse menu shows under "Explain Easier".

## Part A — tooling (one agent, worktree `../scroll-the-quran-simplify-tools`, branch `content/simplify-tools`; no simulator)
Owns: `Tools/content-gen/{author.mjs,validate.mjs,assemble.mjs,sync-study-content.mjs,lib/**,prompts/**,schema/**,README.md}`, `Packages/ScrollKit/Sources/StudyContent/**` (add the optional field only), `Packages/ScrollKit/Tests/StudyContentTests/**`, `docs/tasks/content-simplify.md` (append the exact agent instructions you settle on under "Part B").
1. `lib/readability.mjs`: Flesch–Kincaid grade + mean sentence length, with the same syllable heuristic on both sides (tests in `Tools/content-gen/test/`).
2. `validate.mjs`: a readability rule — error above the targets for units whose `meta.simplified` is set; warning otherwise (so the unsimplified corpus still validates). Also validate `explainEasier` (optional; 25–50 words; grade ≤ 6; no Arabic script).
3. `author.mjs rewrite <key>` / `rewrite-todo [--only discover|surah:N|keys:…] [--limit N]` / `rewrite-dir bodies/`: prints a rewrite prompt = `prompts/simplify.md` (write it: keep every fact, honorific rule, no-ruling rule, word-count ranges; shorten sentences; replace abstract Latinate words with plain ones; do not add new claims; keep `keyTerms`, `crossReferences`, `exploreFurther`, `title`, `theme` untouched unless the wording rules require) followed by the current unit JSON; `rewrite-dir` validates each body with the full rule set + readability, writes it to `work/cache/` with `meta.simplified = "<promptVersion>"` and `meta.author`, and `assemble` picks it up as before. Rewrites must keep `key`, `theme`, `themeId`, `tier`, and the `keyTerms[].arabic` verbatim (validator checks).
4. `schema/`: add `explainEasier` (optional string) and `meta.simplified`. Swift `StudyUnit` gets `public let explainEasier: String?` (decode-if-present), test that a shard with and without the field decodes.
5. `sync-study-content.mjs --prune` still round-trips; `Tools/verify.sh --skip-sim` PASS. Merge with `--no-ff`; remove the worktree.

## Pass 2 — the voice pass (owner, 2026-09-13)
Pass one ("p1") reached 1,708 units and was stopped: it lowered the grade but kept an analytical voice. The standard is now `docs/content/voice.md` + `prompts/simplify.md` (rewritten), stamped `meta.simplified: "v2"` (`lib/voice.mjs`). `rewrite-todo` lists every unit not yet at v2, including the p1 ones; the validator adds voice rules (structure-talk, fragment stacks) for v2 units. Part B's commands are unchanged.

## Part B — rewrite waves (many agents; each in its own worktree `../scroll-the-quran-simplify-<shard>`, branch `content/simplify-<shard>`)
Filled in by Part A's agent with the exact commands. Wave 1 covers the 326 Discover units (`--only discover`), ~55 units per agent; later waves cover the rest by surah range. Each agent: `rewrite-todo` → for each key `rewrite <key>` → write the rewritten body (JSON) → `rewrite-dir` → `assemble` → `validate.mjs out/study` → `sync-study-content.mjs --prune` → `swift test --filter StudyContentTests` → commit. The orchestrator merges (per-unit 3-way JSON merges are known to work: `Tools/content-gen/merge-shards.py`).

### Part B in full — what a rewrite agent runs, in order

Part A landed the tooling (branch `content/simplify-tools`). Everything below is
copy-pasteable. `<shard>` is your wave's name, e.g. `discover-1`. Substitute
nothing else.

**One rule above all the others: never edit `Tools/content-gen/out/study/*.json`
or `Content/study/*.json` by hand.** The only way content changes is
write → `rewrite-dir` → `assemble` → `validate` → `sync`.

#### 1. Set up

```bash
cd /Users/zsha/Documents/scroll-the-quran
git worktree add ../scroll-the-quran-simplify-<shard> -b content/simplify-<shard>
cd ../scroll-the-quran-simplify-<shard>/Tools/content-gen
npm ci                      # node_modules is gitignored; a fresh worktree has none
mkdir -p work/bodies        # your scratch dir; work/ is gitignored, so it never gets committed
```

#### 2. Claim your slice

```bash
node author.mjs rewrite-todo --only discover --limit 55          # wave 1
node author.mjs rewrite-todo --only surah:39 --json              # later waves
node author.mjs rewrite-todo --only keys:2:255,94:5-6 --json     # an explicit slice
```

`rewrite-todo` lists units that **already exist** and have not been through the
pass, each with the grade of its worst section and which sections are over
their ceiling. The orchestrator gives you a key list; use
`--only keys:<a>,<b>,…` so two agents never claim the same unit. Save the list —
it is your checklist.

#### 3. For each key: read the turn, write the body

```bash
node author.mjs rewrite 2:255
```

That prints, in one turn: `prompts/simplify.md` (the rules), the passage in
English, what each section measures today against its ceiling, and the current
body as JSON. Read all of it. Then write the rewritten body to

```
work/bodies/<key with ":" replaced by "_">.json    e.g. work/bodies/2_255.json, work/bodies/94_5-6.json
```

The file is **one JSON object, exactly these fields, nothing else**:

```json
{
  "theme": "Oneness of God",
  "themeId": "tawhid",
  "title": "The Throne Verse",
  "meaning": "…45-105 words, grade ≤ 8.5…",
  "historicalContext": "…40-90 words, grade ≤ 9.5…",
  "keyTerms": [
    { "arabic": "ٱلْقَيُّومُ", "gloss": "the Sustainer", "note": "…15-45 words…" },
    { "arabic": "ٱلْكُرْسِىُّ", "gloss": "the Throne", "note": "…15-45 words…" }
  ],
  "lifeInProphetsTime": "…40-90 words, grade ≤ 8.5…",
  "didYouKnow": "…30-80 words, grade ≤ 9.5…",
  "theologicalSignificance": "…40-95 words, grade ≤ 8.5…",
  "crossReferences": [
    { "ref": "39:53", "why": "…8-30 words…" },
    { "ref": "112:1-4", "why": "…8-30 words…" }
  ],
  "applyIt": "…30-80 words, grade ≤ 8.5…",
  "exploreFurther": ["112:1-4", "59:22-24"],
  "explainEasier": "…25-50 words, grade ≤ 6, the new field…"
}
```

- **Do not write** `key`, `surah`, `start`, `end`, `tier` or `meta`. `assemble.mjs`
  stamps them; a body that carries them is rejected.
- **Copy `theme`, `themeId` and every `keyTerms[].arabic` through character for
  character** from the JSON `rewrite` printed. Never retype Arabic — copy-paste
  it. (`resolve-arabic.mjs` exists for the rare case where you must resolve a
  token; you should not need it here.)
- `crossReferences[].ref` and `exploreFurther` keep the same passages in the
  same order. Their `why` clauses are prose and may be simplified.
- Every prose section also averages **20 words per sentence or fewer**.
- Keep every fact. Add none. The rest of the rules are in the printed prompt.

Work a whole batch into `work/bodies/` before validating: `rewrite-dir` is
all-or-nothing, so one file at a time is slower, not safer.

#### 4. Validate and cache the batch

```bash
node author.mjs rewrite-dir work/bodies/
```

Nothing is written unless every body is clean. Findings print as
`ERROR <key>: <what>` and `WARN <key>: <what>`; warnings do not block. The ones
you will actually see:

| line | what to do |
|---|---|
| `ERROR 2:255: readability above target — meaning grade 10.4 > 8.5` | split the long sentences in `meaning`, then swap Latinate words for plain ones |
| `ERROR 2:255: readability above target — didYouKnow 24.6 words/sentence > 20` | the words may be fine; the sentences are too long. Cut them in two |
| `ERROR 2:255: explainEasier missing (a simplified unit must carry it)` | write the field; it is required on every rewrite |
| `ERROR 2:255: explainEasier is 19 words, must be 25-50` | word bounds are hard, in both directions |
| `ERROR 2:255: explainEasier grade 7.4 > 6` | shorter sentences and smaller words; it is for a twelve-year-old |
| `ERROR 2:255: themeId changed from "tawhid" to "mercy"` | you may not re-theme a unit. Put the original back |
| `ERROR 2:255: keyTerms[].arabic must stay verbatim (was 3 term(s): …)` | you retyped or reordered the Arabic. Paste the original array back |
| `ERROR 2:255: keyTerms[0].arabic is not copied verbatim from 2:255: … — the text has …` | same thing, caught against the Uthmani text. Paste what the message says the text has |
| `ERROR 2:255: meaning is 112 words, must be 45-105` | you lost or gained material. Re-read the original |
| `ERROR 2:255: applyIt: prescriptive ruling (/\byou must\b/i)` | rephrase; the note describes, it never instructs |
| `ERROR 2:255: didYouKnow is a near-duplicate of 2:254 (0.57)` | your rewrite drifted into another unit's fact. Go back to this unit's own |
| `WARN 2:255: title changed to "…"` | fine if deliberate, otherwise put it back |
| `WARN 2:255: crossReferences point somewhere else than they did` | put the original refs back unless you had a reason |

Fix the named files and re-run the same command until it prints
`N rewrite(s) cached.`

#### 5. Assemble, validate, sync, test

```bash
node author.mjs assemble                       # work/cache -> out/study shards + discover.json
node validate.mjs out/study                    # must end "OK" — this is the gate
node sync-study-content.mjs --prune            # out/ -> Content/
cd ../../Packages/ScrollKit && swift test --filter StudyContentTests
```

`validate.mjs out/study` ends with a single collapsed line counting the units
that are still unsimplified — that is expected and is not your batch. Your
batch must produce **0 errors**. Then confirm your keys are done:

```bash
cd ../../Tools/content-gen && node author.mjs rewrite-todo --only keys:<your,keys>
# -> "0 unit(s) to rewrite"
```

#### 6. Commit

Only these files change. `work/` is gitignored and must never be committed —
check with `git status --short` before you stage anything.

```bash
cd /Users/zsha/Documents/scroll-the-quran-simplify-<shard>
git add Tools/content-gen/out/study Tools/content-gen/out/discover.json Content/study
git commit -m "content: simplify <shard> (N units to grade 8.5, explainEasier added)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Report back: the key list, the `rewrite-dir` tail, the `validate.mjs out/study`
tail, the `swift test` tail, and any unit you could not bring inside its ceiling
without losing a fact (leave that one unsimplified rather than thinning it).

#### Merging (orchestrator)

There is **no `merge-shards.py`** in the repo, and none is needed.

Inside a worktree, `assemble.mjs` is already merge-aware: it starts from every
shard committed in `out/study` and lets `work/cache` records replace or add
studies **by key**, so a wave only ever rewrites the units it claimed and a shard
nobody touched keeps its `generatedAt`.

Across branches, the shards are what git sees (`work/` is gitignored and stays in
the wave's worktree). Merge each wave with `git merge --no-ff`. Waves are sliced
by key, so a conflict inside `out/study/surah_NNN.json` is textual, not semantic:
resolve it by keeping **both sides' units** — union the `studies` array by `key`,
sorted by `start` then `end` — and leave `generatedAt` at whichever side is
later. Only `out/` needs resolving by hand; then re-derive and re-check from the
merged checkout:

```bash
node Tools/content-gen/validate.mjs Tools/content-gen/out/study   # must end "OK"
node Tools/content-gen/sync-study-content.mjs --prune             # re-copies out/ -> Content/
cd Packages/ScrollKit && swift test --filter StudyContentTests
```

If a conflict is ever more than textual (two waves claimed the same key), take
the side whose `meta.simplified` is set; if both are, take either and say so in
the merge commit.
