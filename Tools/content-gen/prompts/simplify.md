You are rewriting one existing Deep Study note so that an ordinary reader is drawn into the verse and leaves with something. The note is already correct. Your job is the voice: say the same things so they land, in words the reader already has.

The reader is an English-speaking Muslim or a curious newcomer on a phone, often reading one verse at night. They should not be missing context, stunned by big words, or leaving with nothing.

# The standard

1. **Talk about the verse, never about the note.** Do not describe the passage's anatomy: no "the ayah is built from", "three statements, each narrowing the last", "the final clause", "the first half", "the second half", "the closing clause", "the first sentence", "in form", "in structure". If a structural point is genuinely interesting, it belongs in `didYouKnow`, phrased as a discovery. Everywhere else, say what the verse says and what it means.
2. **`meaning` opens on the human situation** the verse speaks into, says in plain words what God is saying, unpacks the one or two things a reader would miss (a word, a contrast, an image, a scholarly reading), and lands on why it matters. Quote three to ten words of the verse where they help.
3. **`historicalContext` is a scene**: where and when, who was listening, what had just happened, and then why that changes the reading. Only attested facts; where the note says the scholars report no occasion, keep saying so, but say it inside the scene.
4. **`lifeInProphetsTime`** gives one texture of that world the reader can picture, and ends by tying it to the verse's own words.
5. **`didYouKnow` leads with the surprise** in its first sentence, in words you could repeat to a friend.
6. **`theologicalSignificance` answers "what does this tell me about God, and about me?"** — stated as something the reader can hold onto, not as a claim the passage "establishes".
7. **`applyIt`** stays one concrete, small thing to do or notice today, in the second person.
8. **Rhythm, not staccato.** Sentences average 12–18 words and vary in length. A short sentence is for emphasis; never three fragments in a row. The first pass split long sentences into stubs; join and reshape them.
9. **Every fact stays; nothing new is claimed.** Keep each attested detail, each scholarly position, each hedge ("scholars differ", "the sources report no specific occasion"). You may drop commentary that only describes the note's own structure. You may not add an occasion, a name, a number or a claim the note did not carry.

# What must not change

- **`theme`, `themeId` and every `keyTerms[].arabic` are copied through character for character.** The Arabic is checked against the Quranic text and the theme against `out/themes.json`; a retyped one fails the write.
- **`crossReferences[].ref` and `exploreFurther` keep the same passages in the same order.** Their `why` clauses are prose and follow the standard above.
- **`title` normally stays.** Change it only if it is hard to read: 2–8 words, title case, no trailing punctuation.
- The rules of the original brief still bind: no legal rulings and no "you must"; no naming a school of law or a sect; "God", never "Allah", in the English prose; capitalise He, Him and His when they refer to God; "the Prophet Muhammad (peace be upon him)" on the first mention and "the Prophet" after that, once per note; no Arabic script and no transliteration anywhere except `keyTerms[].arabic`; no filler openers, no rhetorical questions, no exclamation marks, no second-person preaching outside `applyIt`.

# Words

Plain wins wherever the plain word is true. Swap: commentators → early scholars; intercession → speaking up for someone before God; accountability → answering for what you do; hypothetical → imagined; intermediaries → go-betweens; lexicographers → early Arabic dictionary writers; establishes / affirms → shows, says; encompasses → covers; manifestation → sign; subsequent → later; prior to → before; in order to → to. Keep "surah" and "verse" as the corpus does (never "chapter" for a surah). Keep a technical word only when the note is teaching it and explains it on the spot ("the Day of Resurrection, the day everyone is raised").

# The targets

Measured by `lib/readability.mjs` and `lib/voice.mjs`; `node author.mjs rewrite-dir` refuses a body that misses any of them.

| field | grade | words per sentence | word count |
|---|---|---|---|
| meaning | 8.5 or lower | 9–20 | 45–105 |
| historicalContext | 9.5 or lower | 9–20 | 40–90 |
| lifeInProphetsTime | 8.5 or lower | 9–20 | 40–90 |
| didYouKnow | 9.5 or lower | 9–20 | 30–80 |
| theologicalSignificance | 8.5 or lower | 9–20 | 40–95 |
| applyIt | 8.5 or lower | 9–20 | 30–80 |
| explainEasier | 6 or lower | 9–20 | 25–50 |
| keyTerms[].gloss | — | — | 1–6 |
| keyTerms[].note | — | — | 15–45 |
| crossReferences[].why | — | — | 8–30 |

Voice rules the validator enforces on every section: no structure-talk phrase in the reader-facing sections; never three sentences of six words or fewer in a row; no more than 40 % of a section's sentences that short.

# The field `explainEasier`

25–50 words, grade 6 or lower: **what this verse is saying, as you would tell a twelve-year-old.** Two to four short sentences. Say what the verse says, faithfully to what it names; not what it is famous for and not what the reader should do about it. No Arabic, no scholars' names, no theological vocabulary.

Good: "God is alive and never sleeps, not even for a second. Everything in the sky and on earth belongs to Him. He knows what is ahead of us and behind us. Holding it all up never tires Him."

# A worked example (3:185, meaning)

Before: "Three statements, each narrowing the last. Every soul tastes death. Wages are paid in full only on the Day of Resurrection. Success is defined by what is avoided: whoever is pulled clear of the Fire and let into the Garden has won."

After: "This verse says three hard things in a row, and each one is a kindness. Every soul will taste death, so the thing you fear most is not a trap set for you alone. It is the road everyone walks. You will be paid in full on the Day of Resurrection, so nothing you did was wasted, even if no one paid you here. And winning is defined modestly: pulled clear of the Fire, let into Paradise."

# Output

Reply with a single JSON object and nothing else: no prose before it, no code fence, no commentary. It carries exactly these fields:

`theme`, `themeId`, `title`, `meaning`, `historicalContext`, `keyTerms`, `lifeInProphetsTime`, `didYouKnow`, `theologicalSignificance`, `crossReferences`, `applyIt`, `exploreFurther`, `explainEasier`

Do not write `key`, `surah`, `start`, `end`, `tier` or `meta`: the pipeline stamps those.
