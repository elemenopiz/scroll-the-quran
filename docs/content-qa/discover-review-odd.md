# Discover review — odd surahs

Judge: Opus agent on `content/qa-discover-a`. Scope: the 161 Discover units whose
surah number is odd (of 326 total; the even half is reviewed separately).

Scoring is 1–5 across the whole rubric in `Tools/content-gen/prompts/system.md`
and `docs/tasks/content-author.md`: grounding in mainstream classical tafsir,
non-sectarian and free of legal rulings, honorific used exactly once, Arabic
confined to `keyTerms` with faithful glosses, every cross-reference real and
genuinely related, `applyIt` warm and concrete and second person, `didYouKnow`
checkable and true, prose varied and not restating the verse.

Anything below 4, and anything with a factual error at any score, was rewritten
through `author.mjs write --force --author opus-judge` → `assemble` → `validate`.
Lexical and structural claims were checked against the bundled corpus with
helpers under `Tools/content-gen/work/authoring/qa-discover-a/`.

| key | score | reason | action |
| --- | --- | --- | --- |
| 1:1-7 | 5 | Structure-led, no paraphrase; "more than twenty names" and the seven-oft-repeated tie to 15:87 both check out. | kept |
| 3:8-9 | 5 | `الوهاب` verified at three occurrences (3:8, 38:9, 38:35); 3:7 / 6:110 / 18:10 all apt. | kept |
| 3:18 | 5 | The "only ayah where God witnesses His own oneness" claim survives checking; 35:28, 58:11, 4:135 real and related. | kept |
| 3:26-27 | 4 | `اللهم` verified at five occurrences; "four of those are prayers" holds only if 8:32 is read as a challenge rather than a prayer — soft edge, not an error. | kept |
| 3:31 | 5 | `يحببكم` occurs only here; the if/then reading is the classical one, cross-refs exact. | kept |
| 3:38 | 5 | Three tellings of Zechariah's prayer confirmed (3:38, 19:2-11, 21:89-90). | kept |
| 3:64 | 5 | Heraclius letter and the 2007 "A Common Word" letter are both checkable; invitation framed non-sectarianly. | kept |
| 3:101-102 | 5 | `يعتصم` → `واعتصموا` two ayat later verified; Aws/Khazraj occasion is the well-attested one. | kept |
| 3:103 | 5 | Rope-as-pact reading attested; 8:63 and 49:10 land exactly. | kept |
| 3:104-105 | 4 | `didYouKnow` claimed the ma'ruf/munkar pair occurs "more than a dozen times"; the corpus has nine (3:104, 3:110, 3:114, 7:157, 9:67, 9:71, 9:112, 22:41, 31:17). | rewritten |
| 3:110 | 5 | The 3:113 qualification three ayat later is correct; the "functional excellence" reading is mainstream. | kept |
| 3:133-134 | 5 | Singular `السماء` at 57:21 vs plural here verified; both do open with a race command. | kept |
| 3:137-139 | 5 | Three terms in 3:138 confirmed; 47:35 does pair the same two roots. | kept |
| 3:145 | 5 | 42:20 harvest parallel accurate; 63:11 apt. | kept |
| 3:159 | 5 | `شورى` occurs once, at 42:38, as claimed; Uhud placement handled without blaming anyone. | kept |
| 3:168-169 | 5 | 2:154 contrast (saying vs supposing) is exactly right. | kept |
| 3:173 | 5 | `حسبنا الله ونعم الوكيل` occurs only here; the Ibn Abbas report is attributed as a report. Honorific not triggered (only a cross-reference clause says "the Prophet"). | kept |
| 3:185 | 5 | "Every soul tastes death" verified at 3:185, 21:35, 29:57 with three different continuations. | kept |
| 3:190-191 | 5 | The four-ayah prayer 191–194 and God's answer at 3:195 both check out. | kept |
| 3:200 | 5 | Two commands from one root confirmed; `رابطوا` range given without picking a school. | kept |
| 5:2 | 5 | The hatred warning does recur six ayat later at 5:8; Hudaybiyya reference is the attested one. | kept |
| 5:8 | 5 | The 4:135 pairing (desire vs hatred) is exact. | kept |
| 5:32 | 5 | Mishnah parallel stated carefully as a parallel, not a borrowing; exceptions handled descriptively. | kept |
| 5:34-35 | 5 | `الوسيلة` verified at exactly two places (5:35, 17:57); no ruling on the punishment passage. | kept |
| 5:54 | 4 | `didYouKnow` counted "five qualities, only one about their relationship with God", which does not survive the count (striving in God's way is a second). | rewritten |
| 5:69 | 5 | The nominative `الصابئون` against the accusative at 2:62 is a real and famous crux; Sabians named three times as stated. | kept |
| 7:26 | 4 | `didYouKnow` said the surah addresses the children of Adam five times; the vocative occurs four times (7:26, 7:27, 7:31, 7:35) plus once at 36:60. | rewritten |
| 7:31 | 4 | Three imperatives and one prohibition is right, but "among the shortest in the Quran to contain" them is a hedge rather than a fact. | kept |
| 7:32 | 5 | Two `قل` commands inside one ayah confirmed; the courtroom reading is apt. | kept |
| 7:55-56 | 5 | `خوفا وطمعا` verified at 7:56, 13:12, 30:24, 32:16; 19:3 is the hidden call as described. | kept |
| 7:180 | 5 | `الأسماء الحسنى` verified at four places (7:180, 17:110, 20:8, 59:24); the 99 figure correctly attributed to a report. | kept |
| 7:199-202 | 4 | `didYouKnow` placed the inner description "two ayat later"; 7:201 is the very next ayah after the command at 7:200. | rewritten |
| 7:203-204 | 5 | The surah's closing prostration two ayat later at 7:206 is correct. | kept |
| 9:40 | 4 | `didYouKnow` said every one of the six occurrences of `سكينة` describes it descending; 2:248 places it in the ark rather than sending it down. | rewritten |
| 9:51 | 3 | `keyTerms[].arabic` was `كَتَبَ لَنَا`, a splice — the passage reads `كَتَبَ ٱللَّهُ لَنَا`; and "the Prophet" was named with no honorific. | rewritten |
| 9:71 | 5 | Ten pairs at 33:35 verified; the 9:67 mirror construction is real. | kept |
| 9:104 | 4 | Strong note; "the Quran uses that verb of God more often than of human beings" is a standard observation I could not count cleanly either way. | kept |
| 9:111 | 5 | 9:111 is the only ayah naming Torah, Gospel and Quran together, and the order is chronological; fighting handled descriptively. | kept |
| 9:119 | 4 | `didYouKnow` called this the last ayah of the expedition passage; 9:120-122 continue it directly. | rewritten |
| 9:128 | 5 | `رءوف رحيم` as a divine pair applied to a man is correct; the last-revealed reports are attributed as reports. | kept |
