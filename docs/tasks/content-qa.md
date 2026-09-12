# Content QA pass (after all waves merge)

Status: the mechanical pass is done on branch `content/qa-tooling`. The
validator gained five rules, 152 findings across 146 units were fixed through
`author.mjs write --force → assemble`, and `node validate.mjs out/study` exits 0
with 0 warnings over all 3,293 units. Numbers below are what each rule actually
found in the first complete corpus.

- [x] Add to validate.mjs: every `keyTerms[].arabic` must occur (diacritics-insensitive, contiguous) in the unit's own Uthmani text; run over the whole corpus and fix offenders (known: 9:51).
      → Made stricter than the brief: the term must occur **verbatim** (NFC,
      contiguous), with the Bismillah prefix of ayah 1 stripped first. The
      diacritics-insensitive pass is the second opinion that picks the error
      message. **111 offenders**: 91 retypes (a dropped tatweel carrier under a
      dagger alef, a bare alef for U+0670, a shadda added or dropped) rewritten
      from the text itself; 20 absences (14 prefix mistakes such as
      `ٱلْمُتَّقِينَ` for `لِلْمُتَّقِينَ`, 6 words from outside the unit including
      9:51) given a corrected or replaced term.
- [x] Add `keyTerms[].gloss` ≤ 6 words note to the author brief (most common failure).
- [ ] Run judge-style review by an Opus agent on a 5% sample + all Discover units against the rubric in Tools/content-gen/prompts/system.md; regenerate anything below 4/5.
      → Not in this pass; two sibling agents are on the Discover set.
- [x] Port hand-written plan fields into Tools/content-gen/build-plans.mjs (it is stale vs Content/plans.json).
      → `image`, `startHere`, the "Recommended for beginners" section and the
      eyebrow/blurb copy ported; section membership is now an explicit ordered
      list with assertions. Verified: re-running the script leaves
      `Content/plans.json` byte-identical. Also fixed its `quran-data.xml` path,
      which did not match where `fetch-inputs.mjs` caches the file.
- [x] validate.mjs: flag a crossReferences/exploreFurther ref that falls inside the unit's own ayah range (e.g. 18:84 on unit 18:83-85).
      → Any overlap is an error, not just an exact self-reference. **41
      offenders** (40 `exploreFurther`, 1 `crossReferences`), all of them a
      surrounding context window that swallowed the unit; each trimmed to the
      side that survives, and 92:1-5's cross-reference re-aimed at 92:6-13 with
      a rewritten `why`.
- [x] search helper: add an `--exact` (NFC, diacritics kept) mode; document the normaliser traps (U+06D6–U+06ED, U+0670, hamza).
      → There was no committed helper (authors kept a private `asearch.mjs`
      under the gitignored `work/authoring`), so `Tools/content-gen/search.mjs`
      is now committed with loose and `--exact` modes, an `--in KEY` answer to
      "is this verbatim in my unit?", and a fallback that lists the tokens
      carrying the term with a prefix. Traps documented in its header, in
      `lib/arabic.mjs`, in the README and in the author brief.
- [x] validate.mjs: reject any non-Latin/non-Arabic script in prose (a stray Cyrillic word slipped past once); reject `keyTerms[].arabic` not copied verbatim (superscript alef U+0670) from the Uthmani text.
      → **0 offenders** for the script rule over the current corpus; the rule
      stands as a regression guard. The verbatim half is the first item above.
- [x] Corpus-wide: detect the same `didYouKnow` fact reused across units (near-dup check currently covers `meaning` only).
      → `didYouKnow` and `applyIt` both covered now, at the same 0.50/0.35
      shingle thresholds. **0 offenders**; the closest pairs are `didYouKnow`
      8:20-22 ~ 8:55-57 at 0.28, `applyIt` 16:14 ~ 41:9-10 at 0.18, `meaning`
      9:94 ~ 9:105 at 0.12. Verified against a brute-force n² sweep, because the
      check now uses an inverted shingle index.
- [x] validate.mjs: `theme` must equal the title of `themeId` in out/themes.json verbatim (78:11-15 and 80:26-30 shipped "The Living Earth" for rain-and-the-earth and only the Swift ThemeIndexTests caught it after sync).
      → **0 offenders**; both known cases had already been repaired by hand
      before this pass. The rule now catches the next one before sync.

## Left for someone else
- The `didYouKnow` of 80:26-30 says "the first two verbs in this passage each
  repeat themselves", but the first of the pair (`صَبًّا`, 80:25) is in the ayah
  before the unit. Prose, not structure, so it belongs to the judge-style
  review rather than to a validator rule.
