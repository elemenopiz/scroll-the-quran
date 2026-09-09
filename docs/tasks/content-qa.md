# Content QA pass (after all waves merge)
- Add to validate.mjs: every `keyTerms[].arabic` must occur (diacritics-insensitive, contiguous) in the unit's own Uthmani text; run over the whole corpus and fix offenders (known: 9:51).
- Add `keyTerms[].gloss` ≤ 6 words note to the author brief (most common failure).
- Run judge-style review by an Opus agent on a 5% sample + all Discover units against the rubric in Tools/content-gen/prompts/system.md; regenerate anything below 4/5.
- Port hand-written plan fields into Tools/content-gen/build-plans.mjs (it is stale vs Content/plans.json).
