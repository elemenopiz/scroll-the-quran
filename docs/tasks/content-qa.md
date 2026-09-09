# Content QA pass (after all waves merge)
- Add to validate.mjs: every `keyTerms[].arabic` must occur (diacritics-insensitive, contiguous) in the unit's own Uthmani text; run over the whole corpus and fix offenders (known: 9:51).
- Add `keyTerms[].gloss` ≤ 6 words note to the author brief (most common failure).
- Run judge-style review by an Opus agent on a 5% sample + all Discover units against the rubric in Tools/content-gen/prompts/system.md; regenerate anything below 4/5.
- Port hand-written plan fields into Tools/content-gen/build-plans.mjs (it is stale vs Content/plans.json).
- validate.mjs: flag a crossReferences/exploreFurther ref that falls inside the unit's own ayah range (e.g. 18:84 on unit 18:83-85).
- search helper: add an `--exact` (NFC, diacritics kept) mode; document the normaliser traps (U+06D6–U+06ED, U+0670, hamza).
- validate.mjs: reject any non-Latin/non-Arabic script in prose (a stray Cyrillic word slipped past once); reject `keyTerms[].arabic` not copied verbatim (superscript alef U+0670) from the Uthmani text.
- Corpus-wide: detect the same `didYouKnow` fact reused across units (near-dup check currently covers `meaning` only).
