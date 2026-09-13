# `Tools/content-gen` — Deep Study content pipeline

Node 24, ESM, no build step. Everything here runs offline except the three
scripts that talk to the Claude API (`submit-batch`, `poll-batch`,
`judge-sample`) and `fetch-inputs`.

The pipeline turns the Quran text into ~4,800 study **units**, generates one
Deep Study note per unit with Claude Opus 5 through the Message Batches API,
validates the results, and assembles them into per-surah JSON shards that the
`StudyContent` Swift target decodes.

```
fetch-inputs → segment-passages → themes → build-requests → submit-batch
             → poll-batch → validate → assemble → judge-sample
```

## Setup

```bash
cd Tools/content-gen
npm install                 # @anthropic-ai/sdk, ajv
node fetch-inputs.mjs       # only needed until the 2a ingest task lands
npm test                    # 25 node --test cases
```

`lib/data.mjs` prefers `out/quran/{surahs,itani,arabic-uthmani}.json` (produced
and committed by the 2a data-ingest task). Until those exist it falls back to
raw downloads cached in `work/quran/`. `work/` is gitignored in its entirety.

### Credentials

The Anthropic API key is read from the environment by the SDK. Run the paid
steps in a subshell that sources the shell profile so the key never lands in a
file, a log, or a commit:

```bash
zsh -c 'source ~/.zshrc; node submit-batch.mjs p1-claude-opus-5-discover'
```

`submit-batch.mjs` and `judge-sample.mjs` refuse to run when
`ANTHROPIC_BASE_URL` points anywhere other than `api.anthropic.com`: the
Message Batches API and `claude-opus-5` exist only there, and Quran content
must not be routed through a third-party relay.

## Commands

### `node fetch-inputs.mjs [--force]`

Downloads the Itani translation, the Uthmani Arabic text, and Tanzil's
`quran-data.xml` into `work/quran/`. Skips files already present.

### `node segment-passages.mjs [--stats] [--min-own-words N] [--max-ayat N] [--max-words N]`

Deterministic segmentation, no LLM and no network. Rules: an ayah of ≥ 12
words is its own unit; shorter ayat merge with their neighbours up to 5 ayat /
60 words; units never cross a surah boundary; every range in
`named-passages.json` is exactly one unit.

Writes `out/study/passages.json` (all 6,236 ayah keys → unit key) and
`work/units.jsonl`. Prints the unit count and asserts full coverage.

`--stats` prints a unit-count sensitivity table instead of writing anything.

> **Unit count.** With the specified thresholds the corpus segments into
> **4,766 units**, not the 3,000–3,400 the plan estimated. 4,440 of the 6,236
> ayat already reach 12 words in the Itani translation, so 4,440 is the floor
> for any rule of that shape. Raising `--min-own-words` to 24 lands in the
> planned range (3,293 units) at the cost of merging genuinely distinct ayat.
> The choice is a cost decision for the full run, so it is left as a flag.

### `node themes.mjs`

Writes `out/themes.json` (50 themes: `{id, title, blurb, refs}`) and
`out/themes-index.json` (ayah key → theme ids, used as the prompt hint).
Fails if any ref is out of bounds, any id is duplicated, or fewer than 40
themes are defined.

The preferred source, QUL Ayah Themes resource 62, is gated behind a QUL
account (checked 2026-09-09 — the only download control targets
`/users/sign_in`). No account was created, so the list is hand-curated and no
QUL data is redistributed. Details in the script header.

### `node build-requests.mjs [--dry-run] [--only discover|all|surah:N] [--model …] [--effort …] [--limit N] [--force] [--out NAME]`

Builds the batch request records. **Always run with `--dry-run` first** — it
prints the request count, the input/output token estimate, and the dollar
estimate, and writes nothing.

- `--only discover` (default) — the 329 units resolved from `discover-seed.txt`
- `--only all` — every unit. Do not run this without the orchestrator's say-so.
- `--only surah:N` — one surah, useful for spot checks
- `--model` defaults to `claude-opus-5`; `--effort` defaults to `medium`
- `--force` re-requests units already answered in `work/cache/`

Token counts come from the free `/v1/messages/count_tokens` endpoint when a
working Anthropic credential is present, and from a character heuristic
otherwise; the output line says which was used. Costs assume the Message
Batches 50% discount and prompt caching of the system prefix.

Output: `work/requests/<name>.jsonl` and `<name>.meta.json`.

**custom_id.** The logical id is `p1:<model>:<key>` as specified. The Batches
API restricts `custom_id` to `[A-Za-z0-9_-]{1,64}`, so the wire form replaces
the separators with `--` and the key's colon with `_`:
`p1:claude-opus-5:2:255-257` → `p1--claude-opus-5--2_255-257`.
`decodeCustomId` reverses it.

**Prompt caching.** The system prompt is two blocks — `prompts/system.md` and
the theme list — identical for every request in a run, with the cache
breakpoint on the second. Everything per-unit lives in the user turn, after
the breakpoint. Verify with `usage.cache_read_input_tokens` in `work/cache/`.

### `node submit-batch.mjs <name> [--max-cost 15] [--confirm]`

Submits `work/requests/<name>.jsonl`, chunked at 10,000 requests per batch.
Refuses to submit when the recorded estimate exceeds `--max-cost` unless
`--confirm` is given. Prints every batch id and appends them to
`work/batches.json`.

### `node poll-batch.mjs (--all | msgbatch_…) [--watch]`

Retrieves batch status. When a batch has `ended`, streams its results and
writes each success to `work/cache/<promptVersion>--<model>--<key>.json`
(results arrive in any order and are matched by `custom_id`, never by
position). Without `--watch` it polls once and exits, so a long batch can be
left and picked up in a later session from `work/batches.json`.

### `node validate.mjs <dir>`

`node validate.mjs out/study` is the gate. Also accepts `work/cache` (raw
results, before assembly) and any directory of study JSON. Exits non-zero on
any error. Checks:

- the ajv schema in `schema/study.schema.json`
- word bounds for every prose field, from that schema's `x-wordBounds`
- Arabic script appears **only** in `keyTerms[].arabic`, and that field must
  be Arabic script with no Latin letters
- **`keyTerms[].arabic` occurs verbatim in the unit's own Uthmani text** —
  NFC, contiguous, every mark kept, with the Bismillah prefix of ayah 1
  stripped first so it cannot supply a term. When the exact match fails a
  diacritics-insensitive second pass decides the message: *not copied
  verbatim* (the word is there, retyped — a dropped tatweel carrier, a plain
  alef for a dagger alef U+0670, a missing annotation sign) names the
  passage's own spelling so the fix is a paste; *does not occur* means the
  word is not in the passage at all, usually because it sits in a neighbouring
  ayah or carries a prefix in the text (`لِلْمُتَّقِينَ`, not `ٱلْمُتَّقِينَ`)
- `theme` is the **title of `themeId`** in `themes.json`, verbatim
- every `crossReferences[].ref` and `exploreFurther` entry is a real
  `surah:ayah` within that surah's ayah count, and **does not overlap the
  unit's own ayat** (a "read next" that leads back to the page you are on)
- prose contains no script but Latin (plus punctuation, digits and combining
  accents): a stray Cyrillic or Greek word is a copy-paste accident
- banned phrasing: legal rulings, sectarian or school-of-law framing, `Allah`
  in English prose, filler openers, model self-reference
- the honorific "(peace be upon him)" accompanies the first naming of the
  Prophet Muhammad
- `key` is an actual unit key from `passages.json`, and `surah`/`start`/`end`
  agree with it; `themeId` exists in `themes.json`
- near-duplicate `meaning`, `didYouKnow` and `applyIt` sections across records
  (5-word shingle Jaccard; ≥ 0.50 errors, ≥ 0.35 warns). Candidate pairs come
  from an inverted shingle index, so the whole corpus validates in seconds.
- **readability**, from `schema/study.schema.json`'s `x-readability` and measured
  by `lib/readability.mjs`: a Flesch-Kincaid grade ceiling per prose section
  (8.5, or 9.5 for `historicalContext` and `didYouKnow`) and a mean sentence
  length of 20 words or fewer. A miss is an **error** on a unit whose
  `meta.simplified` is set — one the simplify pass has already been through —
  and a **warning** on every other unit, so the corpus written before the pass
  still validates. The warnings are collapsed to one summary line; pass
  `--verbose` to list them.
- `explainEasier` where it exists: 25-50 words, grade 6 or below, no Arabic
  script, the same banned phrasing as the rest. It is **required** on a unit
  whose `meta.simplified` is set and optional everywhere else.

### `node search.mjs <arabic term> [--exact] [--in KEY] [--surah N] [--limit N] [--json]`

Finds an Arabic term in the Uthmani text. The default search is
diacritics-insensitive; `--exact` is NFC with every mark kept, which is the
comparison `validate.mjs` actually performs on `keyTerms[].arabic`. When the
loose search hits and `--exact` would not, the text's own spelling is printed
as `exact:` — paste that into the body. `--in 2:153-157` restricts the search
to one unit and then answers the authoring question directly ("verbatim in
2:153-157: yes / NO — the word is there but spelled …").

A search with no hit falls back to listing the tokens that carry the term with
a prefix, because that is the usual reason a key term is not in its passage:
the text has `لِلْمُتَّقِينَ`, not `ٱلْمُتَّقِينَ`.

The normaliser traps it exists to absorb are documented in the file header and
in `lib/arabic.mjs`: U+0640 tatweel as a carrier for the dagger alef, U+0670
superscript alef (a written alef, not a vowel sign), the U+06D6–U+06ED Quranic
annotation signs, U+0671 alef wasla vs a bare alef, U+0649 alef maqsura vs
U+064A ya, the hamza-bearing alefs, and ta marbuta vs ha.

### `node assemble.mjs [--model …] [--only …]`

Reads `work/cache/`, stamps `key`/`surah`/`start`/`end`/`tier`/`meta` onto each
generated body, and writes `out/study/surah_NNN.json`
(`{surah, promptVersion, generatedAt, studies}`, sorted by start ayah, fields
in `x-sectionOrder`) plus `out/discover.json`. Reports which Discover units are
still missing.

### `node judge-sample.mjs [--dry-run] [--sample 0.05] [--effort high] [--confirm]`

Grades assembled studies with Opus 5 against a six-criterion rubric. Every
`discover`-tier unit is graded, plus `--sample` of the rest (deterministic
hash, so the same sample is picked each run). Writes `work/judge/<key>.json`
and lists everything scoring below 4/5 for regeneration at higher effort.
Live calls, no batch discount — `--dry-run` first.

## Authoring mode (no API key)

There is no Anthropic credential for this project, so the batch path
(`build-requests` → `submit-batch` → `poll-batch`) cannot run. Deep Study notes
are written instead by Claude Opus agents inside Claude Code sessions. The agent
*is* the model: it reads the same system prompt and user turn the batch would
have sent, writes the same JSON body, and stores it in `work/cache/` in exactly
the record shape `poll-batch.mjs` produces. Everything downstream — `validate`,
`assemble`, the committed shards — is unchanged.

`author.mjs` is the whole interface. **An author never edits
`out/study/surah_NNN.json` by hand**; shards are only ever produced by
`assemble`.

```bash
node author.mjs todo --only discover --limit 40   # claim a slice
node author.mjs prompt 2:255                      # system + user turn
node author.mjs write 2:255 body.json             # validate, then cache
node author.mjs write-dir bodies/                 # …or a whole directory
node author.mjs assemble                          # cache -> out/study shards
node validate.mjs out/study                       # the gate
node author.mjs status                            # where the wave stands
```

### `node author.mjs todo [--only discover|all|surah:N|keys:a,b] [--limit N] [--json]`

Unit keys that have **no** `work/cache` record and **no** entry in the committed
`out/study` shards, so successive waves never redo work. Prints ayah and word
counts per unit. `--only keys:2:255,1:1-7` claims an explicit list.

### `node author.mjs prompt <key> [--no-system]`

The exact system prompt (`prompts/system.md` plus the theme list, identical to
what `build-requests` builds) followed by the rendered user turn for that unit.
Templating is reused from `lib/prompt.mjs`, never re-implemented.

### `node author.mjs write <key> <body.json> [--author NAME] [--model NAME] [--force]`

Runs the full `validate.mjs` rule set over the body — schema, word bounds from
`x-wordBounds`, Arabic confined to `keyTerms[].arabic`, reference bounds, banned
phrasing, the honorific, `themeId`, key agreement, and near-duplicate `meaning`
against everything already written — and only then writes
`work/cache/p1--<model>--<key>.json`. Exits non-zero with the messages
otherwise. Bodies may still carry the assemble-stamped fields
(`key`/`surah`/`start`/`end`/`tier`/`meta`); they are dropped, and a `key` that
contradicts the target is an error. `--force` allows rewriting a unit that is
already assembled.

`write-dir <dir>` does the same for a directory of `<key>.json` bodies (use `_`
for the `:`, e.g. `2_255.json`). It is all-or-nothing: if any body fails, none
are written.

### `node author.mjs assemble [--only …] [--model …]`

`assemble.mjs`, plus a full per-surah count table and every remaining Discover
gap.

### `node author.mjs status [--model NAME]`

Units total / cached / assembled / Discover remaining, and a per-surah table of
the surahs that have any content.

## The simplify pass

The brief is `docs/tasks/content-simplify.md`; Part B of it is the exact command
list a rewrite agent follows. A rewrite is an ordinary authored body with one
extra marker, so nothing downstream changes:

```bash
node author.mjs rewrite-todo --only discover --limit 55   # claim a slice
node author.mjs rewrite 2:255                             # the whole rewrite turn
#   …write bodies/2_255.json…
node author.mjs rewrite-dir bodies/                       # validate + cache
node author.mjs assemble                                  # cache -> out/study
node validate.mjs out/study                               # the gate
node sync-study-content.mjs --prune                       # out/ -> Content/
```

### `node author.mjs rewrite-todo [--only …] [--limit N] [--json]`

Units that **already exist** and have not been simplified, with the grade of
their worst section and which sections are over their ceiling. (`todo` is the
opposite list: units with nothing written yet.)

### `node author.mjs rewrite <key>`

`prompts/simplify.md`, then the passage in English, then what each section
measures today, then the current body as JSON — the whole turn a rewrite agent
works from. It refuses a key that has no study yet.

### `node author.mjs rewrite-dir <dir> [--author NAME] [--model NAME]`

Like `write-dir`, with three differences: an already-assembled key is the point
rather than a clash, the readability targets are **errors** rather than
warnings, and each body is diffed against the version it replaces —
`theme`, `themeId` and every `keyTerms[].arabic` must be identical, and a moved
`crossReferences[].ref`, `exploreFurther` or `title` warns. Clean bodies are
cached with `simplified` set, which `assemble.mjs` turns into `meta.simplified`
and `meta.author` on the shard. All-or-nothing.

> `meta.simplified` is what makes the readability rule bite. Nothing else marks
> a unit as done: re-running `rewrite-todo` after `assemble` is how a wave
> checks itself.

> **`work/units.jsonl` is gitignored.** `author.mjs` rebuilds it from the
> committed `out/study/passages.json` when it is missing, which is byte-identical
> to what the segmenter produces. Do **not** "fix" a missing unit list by running
> `node segment-passages.mjs` with no flags: its `DEFAULTS.minOwnWords` is 12,
> while the committed `passages.json` was segmented at 24, so a bare re-run
> silently replaces committed content with a different 4,766-unit segmentation.
> If you must regenerate it, pass `--min-own-words 24 --max-words 60`.

The brief future author agents follow is `docs/tasks/content-author.md`.

## Layout

```
schema/study.schema.json    the Study record; x-wordBounds is the single source
                            of truth for validate.mjs
prompts/system.md           cached system prompt (grounding + content rules)
prompts/user.hbs            per-unit user turn template
named-passages.json         47 protected passages segmentation must not split
discover-seed.txt           337 curated refs → 329 Discover units, all 30 juz
lib/data.mjs                Quran text + surah metadata, key/ref helpers
lib/arabic.mjs              NFC/diacritics-insensitive normalisers, the exact-
                            span resolver, stripBasmala
lib/units.mjs               unit selection (discover / all / surah:N) + tiers
lib/prompt.mjs              prompt assembly, output schema, custom_id codec
lib/author.mjs              authoring mode: todo/prompt/validate/write/status,
                            and the simplify pass: rewrite-todo/rewrite/
                            rewrite-dir, fidelity checks, meta.simplified
lib/readability.mjs         Flesch-Kincaid grade + mean sentence length, one
                            syllable heuristic shared by the CLI and validate
prompts/simplify.md         the rewrite prompt: keep every fact, shorten the
                            sentences, plain words, write explainEasier
lib/pricing.mjs             model prices and the cost estimator
out/                        committed pipeline output
work/                       gitignored: raw downloads, requests, cache, judge
author.mjs                  authoring-mode CLI (see "Authoring mode" above)
search.mjs                  find an Arabic term in the Uthmani text (loose /
                            --exact); toks.mjs prints a token index, and
                            resolve-arabic.mjs turns "@S:A/i" into the exact
                            token so no Arabic is ever hand-typed
test/                       node --test suite
```

## Content rules

These are enforced in `prompts/system.md` and re-checked by `validate.mjs`:
mainstream and non-sectarian, grounded in Ibn Kathir, al-Tabari, al-Qurtubi and
al-Sa'di, "scholars differ" where they do, no legal rulings of any kind,
occasions of revelation only when well attested, the honorific once per note,
`applyIt` in the second person, Arabic script confined to `keyTerms[].arabic`
(never transliteration), and every cross-reference inside `surah:ayah` bounds.

## Cost guardrails

- `--dry-run` prints an estimate and writes nothing.
- `submit-batch.mjs` refuses above `--max-cost` (default $15) without
  `--confirm`.
- `work/cache/` means a re-run only pays for units that are missing.
- `--only all` is a deliberate, separate decision. At the current 4,766 units
  and the Discover run's measured per-unit cost, budget roughly 14× the
  Discover figure.
