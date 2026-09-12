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
| 11:6 | 5 | 6:38 parallel about creatures is real and closely built; provision framed as an undertaking, not a guarantee of abundance. | kept |
| 11:88 | 5 | Shu'ayb answering a charge of hypocrisy, stated without turning it into a ruling about trade. | kept |
| 11:112 | 5 | Singular command and plural prohibition in one line verified; the "greyed me" report handled as a report. | kept |
| 11:114-115 | 5 | `يذهبن` does take the good deeds as subject; prayer times described, never prescribed. | kept |
| 13:11 | 5 | Surah 13's four-letter opening is unique and neighbours 10–12, 14–15 do use three; thunder naming correct. | kept |
| 13:17 | 5 | The ayah does say twice that God sets forth comparisons; both halves of the parable land. | kept |
| 13:23-24 | 3 | `didYouKnow` delivered no fact — it noted the greeting is the ordinary one and then told the reader a clause was "worth pausing on". | rewritten |
| 13:28 | 5 | The chiasm reading is exact, and the promise is kept to settling rather than to relief. | kept |
| 15:9-13 | 5 | The doubled emphatic pledge and the Hijr tombs both check out. | kept |
| 15:45-49 | 5 | `ونزعنا ما في صدورهم من غل` verified as identical at 7:43; the 15:49/15:50 pairing is correct. | kept |
| 15:88 | 5 | The wing idiom recurs exactly twice more (17:24, 26:215), as claimed. | kept |
| 17:9 | 5 | The elided noun after the superlative is a real grammatical feature and classically discussed. | kept |
| 17:23-24 | 5 | `أف` as a sound rather than a word, and the "one or both" construction, are both right. | kept |
| 17:36 | 5 | Hearing-sight-heart order holds across the Quran; 41:20-21 is the right partner. | kept |
| 17:37-38 | 5 | 31:18 does pair the same prohibition with the turned cheek. | kept |
| 17:44-45 | 5 | `حجابا مستورا` as a veil that is itself veiled is the classical observation. | kept |
| 17:52-53 | 5 | "My servants" and the 39:53 link are apt; the quarrel is diagnosed without excusing the speaker. | kept |
| 17:70 | 5 | Dignity read as unconditional, with the "many" qualification correctly flagged. | kept |
| 17:80-82 | 5 | `شفاء` of the Quran verified at exactly three places (10:57, 17:82, 41:44), each paired as described. | kept |
| 17:110 | 4 | Sound; the `didYouKnow` about a range set by its two ends is a fair observation rather than a striking fact. | kept |
| 19:4 | 4 | `didYouKnow` put the answer "two ayat later"; Zechariah is addressed by name at 19:7, three ayat after this one. | rewritten |
| 19:96-97 | 5 | `الرحمن` counted: 13 occurrences in surah 19, more than any other surah; `لدا` is a hapax as stated. | kept |
| 21:30 | 3 | `didYouKnow` only restated the two `keyTerms` notes about the sewing vocabulary — no fact the reader did not already have. | rewritten |
| 21:34-35 | 3 | `didYouKnow` reused the "every soul tastes death appears three times" fact already carried by 3:185 in this same Discover set. | rewritten |
| 21:68-71 | 5 | The vocative to the fire and the 11:44 parallel to earth and sky are both correct. | kept |
| 21:82-83 | 5 | Job's prayer is six words and contains no request, as stated; the Solomon/Job pairing is the surah's own. | kept |
| 21:87-88 | 5 | Three-part prayer accurately described; 68:48-50 and 10:98 both real and related. | kept |
| 21:90 | 5 | `رغبا ورهبا` verified as occurring only here; the range on `أصلحنا` reported without settling it. | kept |
| 21:105-108 | 5 | The mercy clause is five words in Arabic and the restrictive construction is correctly read. | kept |
| 23:1-11 | 4 | `الفردوس` verified at exactly two places (18:107, 23:11); "two different words" for the prayer frame is loose — it is one word in two numbers. | kept |
| 23:12-13 | 4 | Sequence and the closing phrase of praise check out; the report of a companion completing it is properly hedged. | kept |
| 23:96-99 | 4 | Sound; the `didYouKnow` describes the prayers' framing rather than delivering a hard fact. | kept |
| 23:113-115 | 5 | `عبثا` verified as a hapax; the surah does close on a prayer for forgiveness at 23:118. | kept |
| 25:20 | 4 | Strong note — the 25:7 / 25:20 repetition thirteen ayat apart is exact — but "the Prophet" was used twice with no honorific. | rewritten |
| 25:43-44 | 5 | The 7:179 parallel is real; idolatry redefined without naming any group. | kept |
| 25:63-68 | 4 | `didYouKnow` said the chain closes the surah; it runs to 25:76 and 25:77 breaks off to address the deniers. | rewritten |
| 25:69-70 | 5 | The exchange of bad deeds for good is unique to 25:70; mercy stated without softening the offences. | kept |
| 25:74 | 4 | `keyTerms[].arabic` was `ٱلْمُتَّقِينَ`; the passage reads `لِلْمُتَّقِينَ`. Everything else, including the count of quoted prayers in the portrait, is right. | rewritten |
| 27:19 | 5 | Ants appear in exactly two ayat of the surah, as stated; Solomon's power kept subordinate throughout. | kept |
| 27:40 | 5 | Surah 27 is the only surah carrying the opening formula twice (27:30); gratitude credited to the grateful. | kept |
| 27:62 | 3 | `didYouKnow` called the refrain a "five-word challenge" — it is three words — and listed four varying endings for five ayat. | rewritten |
| 29:1-4 | 5 | Twenty-nine surahs with disconnected letters is the standard count; the tradition's own uncertainty reported honestly. | kept |
| 29:5-6 | 5 | The striving verb does return in 29:69, the surah's last ayah, as claimed. | kept |
| 29:20 | 5 | 29:20 really is the only place the travel command is turned toward how creation began. | kept |
| 29:45 | 5 | `الفحشاء` / `المنكر` distinction is right; both readings of the closing clause given without a winner. | kept |
| 29:68-69 | 4 | `didYouKnow` said two ayat give the surah its name; `العنكبوت` occurs in one ayah only, 29:41. | rewritten |
| 31:11-12 | 5 | Luqman correctly not called a prophet, origins reported as the commentators differ. | kept |
| 31:13-19 | 5 | The two interrupting ayat and the resumed vocative are exactly as described. | kept |
| 31:27-28 | 5 | The 18:109 parallel with its smaller quantity is correct; "seven" read as indefinite, which is the classical reading. | kept |
| 31:34 | 5 | `الغيث` verified as rare and tied to relief; two of the five items placed inside the reader's own life. | kept |
