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
| 2:249 | 5 | River-then-battle sorting is read straight from the text; "only place Saul and Goliath are named" is true of the Quran as a whole (2:246-251). | kept |
| 2:255 | 5 | Reference exemplar. The footstool note records the classical range rather than choosing. | kept |
| 2:256 | 5 | Occasion given with the variation in the reports acknowledged; no coercion claim stated without overreach. | kept |
| 2:257 | 5 | Plural-darkness / singular-light asymmetry verified corpus-wide (no singular `ظلمة`, no plural of light anywhere). | kept |
| 2:261-262 | 5 | Condition correctly located in the giver's conduct afterwards rather than in the amount; yield described as stretched, not invented. | kept |
| 2:263 | 5 | Ranks a free act above a costly one and explains the ranking from the two closing divine names. | kept |
| 2:270-271 | 5 | The `ك ف ر` / sower-covering-seed etymology is attested (cf. 57:20); refuses the simple rule that hidden giving always wins. | kept |
| 2:274 | 3 | `didYouKnow` called this the fourth occurrence of the "no fear nor grief" refrain in the surah; it is the fifth (2:38 precedes 2:62, 2:112, 2:262), and 2:38 was missing from the list that follows. | rewritten |
| 2:284 | 5 | The community's distress and the answer in the next two ayat are well attested; honorific used once. | kept |
| 2:285-286 | 5 | Records both the Medinan and night-journey reports without forcing a choice. | kept |
| 4:1 | 5 | Shared opening with 22:1 verified; "second longest surah" is the standard word-count measure. | kept |
| 4:32 | 5 | Keeps the classical distinction between wanting the like of something and wanting it taken; 33:35's ten gendered pairs verified. | kept |
| 4:36 | 5 | Nine categories counted correctly and read as widening rings; closing on arrogance is the text's own move. | kept |
| 4:58 | 4 | Excellent; the aside linking the root of "trust" to the word said after a supplication is a commonly repeated etymology that the lexicographers actually dispute. Minor, kept. | kept |
| 4:59 | 5 | The dropped verb before "those in authority" is a real grammatical point and is the load-bearing one in classical commentary. | kept |
| 4:67-69 | 5 | Ties the four ranks to the path requested in the opening surah, which is mainstream; company-not-rank reading is well grounded. | kept |
| 4:79-80 | 5 | Handles the causation/responsibility tension the way the major commentaries do, and says so. | kept |
| 4:85-86 | 5 | Correctly narrows intercession to the everyday sense; the floor-and-ceiling reading of the greeting is exact. | kept |
| 4:110-111 | 5 | "Finds" as a verb of discovery is a real lexical point; forgiveness and non-transferable responsibility held together without tension. | kept |
| 4:135 | 5 | The 4:135 / 5:8 mirroring, with desire and hatred as the two different obstacles, is accurate and well used. | kept |
| 4:136 | 5 | The five objects of belief here and the five in 2:177 match, and neither list is claimed as exhaustive. | kept |
| 6:12 | 5 | "Mercy written upon Himself" verified as occurring only at 6:12 and 6:54; the contract vocabulary is read from the verb, not imposed. | kept |
| 6:15-17 | 5 | Surah 6 does carry the most `qul` in the Quran (44 occurrences), so "more often than in almost any other surah" is safe. | kept |
| 6:32-33 | 5 | The 57:20 five-stage expansion is counted correctly; consolation offered by correcting a fact rather than softening one. | kept |
| 6:38 | 5 | Records the commentators' disagreement over how far the animal-communities comparison reaches; the "two wings" redundancy is a real classical discussion. | kept |
| 6:54-55 | 5 | Contrasts the two occurrences of the written-mercy clause in the same surah to good effect; occasion (the demand to dismiss the poor) is well attested. | kept |
| 6:59 | 5 | Descending-list structure is accurate; `applyIt` turns the cosmic scope onto something unnoticed, which is the ayah's own move. | kept |
| 6:73 | 5 | "Be" and its instant answer occurs eight times, always in the same construction; resurrection argument drawn without overstating. | kept |
| 6:78-79 | 5 | Gives both classical readings of the sequence (personal search vs debating technique) without choosing. | kept |
| 6:81-82 | 5 | Notes early listeners' difficulty with the second ayah and gives the mainstream resolution via 31:13. | kept |
| 6:102-103 | 5 | The Subtle / the Expert pairing does cluster in hidden-thing contexts (6:103, 22:63, 31:16, 33:34, 67:14). | kept |
| 6:151 | 5 | Legal content handled descriptively throughout; `applyIt` turns to the concealed half rather than issuing a ruling. | kept |
| 6:160 | 5 | Correctly reads ten as the floor rather than the ceiling, with 2:261 as the parallel. | kept |
| 6:162-163 | 5 | "First of those who submit" glossed as foremost in this community, which is the mainstream resolution. | kept |
| 8:2 | 5 | Marks of faith read as involuntary responses, which is the classical point; Badr setting is exact. | kept |
| 8:24-25 | 5 | Keeps the ambiguity of "comes between a man and his heart" open, as the commentators do. | kept |
| 8:29 | 5 | The one word naming a book, a day (8:41) and a faculty is a genuine and checkable observation. | kept |
| 8:46 | 5 | "Your wind" read as momentum with the classical gloss; promise is company rather than victory, which the text actually says. | kept |
| 10:25-26 | 5 | "Home of Peace" verified at exactly two occurrences (6:127, 10:25); leaves the unnamed "more" unnamed. | kept |
| 10:57-58 | 5 | Healing-before-guidance order is read off the ayah; the self-description passages are cited with their limits intact. | kept |
