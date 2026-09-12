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
| 10:62-65 | 5 | Defines "friends of God" by the two ordinary qualities the ayah itself gives; keeps the range on the worldly good news open. | kept |
| 10:107 | 5 | The 6:17 / 10:107 asymmetry (touch vs intend) is real and precisely described. | kept |
| 12:4 | 5 | The rational-plural on the prostrating stars is a genuine grammatical point; "only continuous story" and the 12:3 self-description both check out. | kept |
| 12:18 | 5 | "Beautiful patience" occurs twice in the surah, both from Jacob; the shirt-as-thread observation is accurate (18, 25-28, 93). | kept |
| 12:21 | 5 | Providence working through unrelated motives is stated without denying the human motive; the surah's namelessness is a real pattern. | kept |
| 12:87 | 5 | Holds searching and hope in one sentence, which is what the ayah does; the `رَوْح` / spirit / wind relation is attested. | kept |
| 12:91-92 | 5 | Splits pardon into what Joseph can cancel and what only God forgives — exactly what the text does. Conquest-of-Mecca report properly hedged. | kept |
| 12:101 | 5 | "Some of the sovereignty" read from the partitive particle; notes that nothing is asked for in this life, which is true of the prayer. | kept |
| 14:7 | 5 | The broken parallel in the second half is a real classical observation and the best fact available here. | kept |
| 14:24 | 5 | Leaves the tree unnamed and reports both positions; the hidden-root/visible-fruit structure is read from the ayah. | kept |
| 14:34 | 5 | Uncountable-blessings sentence verified at two occurrences (14:34, 16:18) with different sequels; the 55:13 refrain is exactly 31 times. | kept |
| 14:40-41 | 5 | Seven-ayah supplication (14:35-41) counted correctly; "one of only six surahs named after a prophet" is right (10, 11, 12, 14, 47, 71). | kept |
| 16:18-21 | 5 | The bee appears in only two ayat of its own surah (16:68-69); the capability argument is made without polemic. | kept |
| 16:53-55 | 5 | The animal-cry verb is rare (16:53, 23:64, 23:67) and always in this setting, as claimed. | kept |
| 16:90 | 5 | The three-and-three structure is exact; the Friday-pulpit custom and the companion's report are both properly attributed. | kept |
| 16:96 | 5 | The repeated closing clause across 16:96 and 16:97 is verbatim in the Arabic, as claimed. | kept |
| 16:97 | 5 | Notes the singular-to-plural switch inside the ayah; the male-and-female symmetry is described, not editorialised. | kept |
| 16:125 | 5 | "Spends all its words on the caller and almost none on the message" is a true and useful observation. | kept |
| 16:127-128 | 5 | 128-ayah count correct; reframes exhaustion as a reason to ask rather than evidence of failure. | kept |
| 18:1-10 | 5 | The saktah after `عِوَجَا` is one of the four in the Hafs text, correctly called rare; the three-questions report is hedged. | kept |
| 18:23-25 | 5 | The 300 solar / 309 lunar correspondence is a genuine classical observation and is the best available fact here. | kept |
| 18:28 | 5 | Occasion (the request to exclude the poor believers) attested and handled without naming anyone; `زينة` recurs three times in the surah as claimed. | kept |
| 18:30 | 5 | The grammatical resumption is real; promise correctly read as a denial of loss rather than a description of gain. | kept |
| 18:46 | 5 | "The lasting good things" verified at two occurrences (18:46, 19:76); both classical readings of the phrase kept open. | kept |
| 18:107-110 | 5 | `الفردوس` verified at exactly two occurrences (18:107, 23:11); the ink/supply wordplay is real in the Arabic. | kept |
| 20:11-14 | 5 | Lists the classical readings of "for My remembrance" without choosing; Tuwa verified at only 20:12 and 79:16. | kept |
| 20:25-28 | 5 | Twelve-word prayer counted correctly; asks for capacity, not a different assignment, which is the text's own shape. | kept |
| 20:114 | 5 | The 75:16-19 parallel is exact; "the one place the instruction is to ask for more" is a fair and checkable claim. | kept |
| 20:124 | 5 | `ضَنكًا` verified as a single occurrence in the Quran, which is what makes the commentary range meaningful. | kept |
| 20:130 | 5 | The two recognised readings of the final word are both transmitted and are presented as complementary, not competing. | kept |
| 20:131 | 5 | The 15:88 parallel and what each passage adds is accurately described; the smelting sense of the test-verb is attested. | kept |
| 22:5 | 5 | Argument from precedent rather than power, which is the ayah's own method; the mixed Meccan/Medinan note is properly hedged. | kept |
| 22:32-33 | 4 | Content is excellent (two sajdahs unique to this surah; `البيت العتيق` only here, twice). Nit: `exploreFurther[0]` is 22:26-37, a range containing the unit's own ayat. | kept |
| 22:46 | 5 | The structural point about eyes being left out of the first half and dismissed in the second is true and well made. | kept |
| 22:78 | 5 | Records the old division over who did the naming without declaring a winner. | kept |
| 24:22 | 5 | Well-attested occasion given without naming the parties, which avoids a sectarian-sensitive identification; pardon tied to a resumed payment. | kept |
| 24:26 | 5 | Both classical readings (people / speech) given; the chiasm observation is accurate. | kept |
| 24:35 | 5 | Holds the classical line that the parable is of His light, not of Him; `مشكاة` verified as a single occurrence. | kept |
| 24:55 | 5 | Succession read as a turn that ends, which is what the root gives; condition stated as the text states it. | kept |
| 26:79-83 | 5 | 227 ayat and the eightfold refrain both check out; the self-attribution of illness is given the classical courtesy-of-speech reading. | kept |
| 26:84-88 | 5 | The petition at 26:84 and its grant at 19:50 use the same two-word phrase, as claimed; `applyIt` is imperative second person and concrete. | kept |
| 28:55-56 | 5 | Sectarian-sensitive occasion handled exactly right: the setting is described, the relative is not named. Surah-name observation (28:25) checks out. | kept |
| 28:77 | 3 | `didYouKnow` said Qarun is named three times in the Quran; he is named four times (28:76, 28:79, 29:39, 40:24 — twice in this surah alone). | rewritten |
| 28:83 | 5 | The `علو` root opening the surah at 28:4 and closing it here is a real and well-used structural observation. | kept |
| 30:21 | 4 | Excellent content; the run of four sign-ayat with four different closing faculties (30:21-24) is exactly right. Nit: `exploreFurther[2]` is 30:20-25, containing the unit. | kept |
| 30:22 | 4 | Human variety given theological status without editorialising; `اختلاف` as both difference and alternation is accurate. Same `exploreFurther` overlap nit. | kept |
| 30:29-30 | 5 | Gives both readings of "no altering of God's creation"; the `فطر` / Eid al-Fitr root connection is correct. | kept |
| 30:41-42 | 5 | Consequence framed as instructive rather than as settlement, which is what the ayah's purpose clause says. | kept |
| 30:49-50 | 4 | "Earth revived after its death" verified at three places in this surah (30:19, 30:24, 30:50). Nit: `exploreFurther[0]` is 30:46-50, containing the unit. | kept |
| 30:59-60 | 5 | The Byzantine prediction is correctly placed at the surah's opening; patience read as steadiness rather than endurance of pain. | kept |
| 32:16 | 4 | Fear and hope held in balance without subordinating either, which is the classical description. Nit: `exploreFurther[2]` is 32:15-19, containing the unit. | kept |
| 32:17-19 | 5 | The divine saying is quoted as a report the commentators cite, not as scripture; hospitality reading of `نُزُل` is precise. | kept |
| 34:13 | 5 | `الشكور` as a divine name twice in surah 35 (35:30, 35:34) checks out; gratitude located inside the labour, as the grammar has it. | kept |
| 34:38-39 | 5 | Separates "provision is from God" from "provision measures approval" — the distinction the passage is actually making. | kept |
| 36:12-13 | 5 | Traces read in both directions (unintended good and damage left running), which is the classical range. | kept |
| 36:36 | 4 | The deliberately open third clause is well handled; `أزواج` ambiguity explained honestly. Nit: `exploreFurther[0]` is 36:33-40, containing the unit. | kept |
| 36:40-42 | 4 | The `فلك` orbit/ship consonantal pun is real and is the best fact here. Nit: `exploreFurther[0]` is 36:37-44, containing the unit. | kept |
| 36:57-61 | 4 | "Children of Adam" verified at exactly five places (7:26, 7:27, 7:31, 7:35, 36:60), four of them in surah 7. Nit: `exploreFurther[0]` is 36:51-58, overlapping the unit. | kept |
| 36:82-83 | 3 | `didYouKnow` said `ملكوت` is twice what Abraham was shown; of its four occurrences only 6:75 is Abraham, while 7:185 and 23:88 are both questions put to rejectors. | rewritten |
| 38:26 | 5 | `خليفة` in the singular verified at exactly two places (2:30, 38:26); desire correctly named as the mechanism that moves a judge before it bends a verdict. | kept |
| 38:29-31 | 5 | `صافنات` described from the lexicographers rather than invented; the 54:17 fourfold refrain is counted correctly. | kept |
| 40:44-45 | 5 | Reliance correctly placed after the speaking, not instead of it; the surah's two traditional names are accurate. | kept |
| 40:59-60 | 5 | The supplication-is-worship report is cited as a report; asking classed as worship, which is what the ayah's join does. | kept |
| 42:11 | 5 | The doubled `كمثله` construction and the grammarians' reading of it are reported accurately. | kept |
| 42:23 | 5 | Sectarian-sensitive passage handled exactly as the brief requires: all classical readings of the exception given, none preferred. Five identical refusals in surah 26 verified. | kept |
| 42:30-32 | 4 | "He pardons much" verified at 42:30 and 42:34, as claimed; refuses to let circumstances be read backwards as a verdict. Nit: `exploreFurther[0]` is 42:27-35, containing the unit. | kept |
| 42:40 | 4 | Names the surah correctly from 42:38; distinguishes pardon from repair, which is what the second verb means. Nit: `exploreFurther[0]` is 42:36-43, containing the unit. | kept |
| 42:41-43 | 4 | Holds the right to redress and the choice to forgo it together, which is the passage's own balance. Same `exploreFurther` overlap nit. | kept |
| 44:34-38 | 4 | Tubba verified at exactly two places (44:37, 50:14) and correctly described as a royal title. Nit: `exploreFurther[0]` is 44:38-42, overlapping the unit. | kept |
| 46:15 | 5 | The six-month deduction is a genuine early reading, given without naming the authority; `أوزعني` verified as shared only with 27:19. | kept |
| 48:1-3 | 5 | Hudaybiyyah occasion accurate and well told; forgiveness correctly read as the purpose of the opening rather than its reward. | kept |
| 48:4 | 5 | `سكينة` verified at six occurrences, three of them in this surah, with the other three correctly identified. | kept |
| 48:29 | 5 | "Muhammad" verified at exactly four places (3:144, 33:40, 47:2, 48:29), with 61:6 noted separately as Ahmad. | kept |
| 50:15-17 | 5 | Three single-letter openings (38, 50, 68) is correct; the Friday-recitation report is properly attributed. | kept |
| 50:34-37 | 5 | Leaves `مزيد` unspecified as the grammar does, and cites the sight-of-God explanation as a report rather than as the meaning. | kept |
| 54:13-17 | 5 | The fourfold "made easy" refrain and the sixfold `مدكر` (54:15, 17, 22, 32, 40, 51 — nowhere else) both verified. | kept |
| 56:6-10 | 5 | The unique three-way sorting and its return at 56:88-94 are both accurate. | kept |
| 58:11 | 5 | Verified against the corpus: surah 58 is the only surah carrying the divine name in every one of its 22 ayat. | kept |
| 62:9-10 | 5 | `الجمعة` verified as a single occurrence; the passage read as an interruption with a defined edge, which both ayat support. | kept |
| 64:11-13 | 5 | Declines to answer the theodicy question, as the ayah does, and says so; the companion's gloss is cited as a gloss. | kept |
