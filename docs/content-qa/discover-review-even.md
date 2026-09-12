# Discover review — even surahs

Judge: Opus agent on `content/qa-discover-b`. Scope: the 165 Discover units
(`Tools/content-gen/out/discover.json`) whose surah number is even, out of the
curated set of 326. Sibling review of the odd surahs is tracked separately.

Each unit was read against its passage (Arabic + Itani translation) and scored
1–5 on: grounding in mainstream classical tafsir with no invented claims;
non-sectarian and free of legal rulings; the honorific used exactly once; Arabic
confined to `keyTerms` with faithful glosses; every cross-reference real and
genuinely related; `applyIt` warm, concrete, second person and doable;
`didYouKnow` checkable and true; prose varied and not restating the verse.

Lexical and structural claims were checked against the bundled corpus
(`out/quran/arabic-uthmani.json`, `itani.json`) with helpers kept under
`Tools/content-gen/work/authoring/qa-discover-b/` (gitignored).

Rewrites go through the sanctioned path only: corrected body →
`author.mjs write --force --author opus-judge` → `assemble` → `validate.mjs`.
No shard was hand-edited.

| Key | Score | Reason | Action |
| --- | --- | --- | --- |
| 2:1-5 | 3 | `didYouKnow` said the detached letters are "always" followed within a few lines by a mention of the Book (false for surahs 29 and 30) and counted "three ayat describing those who reject it" (2:6-7 is two). | rewritten |
| 2:21-22 | 5 | Correctly identifies the Quran's first imperative addressed to all people; the `ع ب د` / well-trodden-road note is attested in the classical lexicons. | kept |
| 2:30 | 5 | Records the commentators' disagreement about the angels' expectation without resolving it; `applyIt` lands the word "deputy" on something the reader actually holds. | kept |
| 2:45-47 | 4 | Strong throughout; `didYouKnow` says the steadfastness-and-prayer pairing recurs "within a hundred ayat" when 2:45 to 2:153 is 108. Hedged enough to keep. | kept |
| 2:62 | 5 | Gives the classical range on scope without picking a winner; 5:69 and 22:17 are the right parallels and are real. | kept |
| 2:112 | 5 | "No fear nor grief" refrain claim checks out (12 exact occurrences corpus-wide); cross-references all real and apt. | kept |
| 2:115-116 | 5 | `keyTerms` note on the face of God records the range and the no-bodily-sense caveat; theme fit (mercy-of-god) is looser than the content but matches `themes.json`. | kept |
| 2:124 | 5 | "Only figure called both leader and a community in himself" verified (16:120); the trial-before-office reading is mainstream. | kept |
| 2:127-128 | 5 | Honorific used once and in the right place; 2:129 link is exact. | kept |
| 2:136 | 5 | Twenty-five named prophets and the Jesus/Muhammad naming frequency both check out; stated without any ranking. | kept |
| 2:143 | 5 | 2:143 is the exact midpoint of a 286-ayah surah; Masjid al-Qiblatayn claim is correct and non-sectarian. | kept |
| 2:152 | 5 | Root `ذ ك ر` count verified at 281 occurrences (claim: "more than two hundred"). | kept |
| 2:153-157 | 5 | Trials read as an inventory of the community's actual conditions rather than as metaphor; `applyIt` practises the phrase on small losses. | kept |
| 2:177 | 5 | The mid-sentence grammatical shift is a genuine classical discussion; six recipient categories counted correctly. | kept |
| 2:183 | 5 | Ramadan as the Quran's only named month verified (2:185 only); stays descriptive about the fast, no ruling. | kept |
| 2:186 | 5 | The missing `qul` is real and is the best fact available for this ayah; `applyIt` asks for plain speech rather than recitation. | kept |
| 2:216 | 5 | Reference exemplar. Stays descriptive about fighting; the particle-of-possibility note is what protects a grieving reader. | kept |
| 2:222 | 4 | Careful, non-legal and warm; `didYouKnow` says the "they ask you" formula occurs "around fifteen times" where the corpus has 13. Hedged. | kept |
| 2:238-239 | 5 | Gives the range on the middle prayer without choosing; al-Tabari attribution is accurate. | kept |
| 2:245 | 5 | "Good loan" phrase verified at exactly six occurrences (2:245, 5:12, 57:11, 57:18, 64:17, 73:20). | kept |
