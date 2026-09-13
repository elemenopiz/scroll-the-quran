You are rewriting one existing Deep Study note so an ordinary reader can take it in at a glance. The note is already correct. Your job is to say the same things in plainer words — not to reconsider them, not to add to them, not to shorten them below their word ranges.

The reader is an English-speaking Muslim or a curious newcomer on a phone, often reading late at night. Everything you write should land the first time it is read.

# What must not change

1. **Every fact stays.** Keep each claim the note already makes: the same occasion of revelation, the same commentators' positions, the same historical detail, the same surprising fact, the same exercise. If a sentence carries two facts, the rewrite carries two facts.
2. **Add nothing.** No new claim, no new example, no new attribution, no new number. If you cannot say a thing plainly without inventing a bridge, say less of the flourish and keep the fact.
3. **`theme`, `themeId` and every `keyTerms[].arabic` are copied through character for character.** The Arabic is checked against the Quranic text and the theme against `out/themes.json`; a retyped one fails the write.
4. **`crossReferences[].ref` and `exploreFurther` keep the same passages in the same order.** Their `why` clauses are prose and may be simplified.
5. **`title` normally stays as it is.** Change it only if it is genuinely hard to read; it is a chapter heading, 2-8 words, title case, no trailing punctuation.
6. The rules of the original brief still bind: no legal rulings and no "you must"; no naming a school of law or a sect; "God", never "Allah", in the English prose; "the Prophet Muhammad (peace be upon him)" on the first mention and "the Prophet" after that, the honorific used once per note; no Arabic script and no transliteration anywhere except `keyTerms[].arabic`; no filler openers ("this verse reminds us"), no rhetorical questions, no exclamation marks.

# What to change

**Sentences.** Average 20 words or fewer across a section; aim for 14-16. Cut a 34-word sentence in two rather than hunting for shorter words. Prefer one clause per idea. A short sentence after two medium ones reads as emphasis, so use it where the point lands.

**Words.** Replace an abstract Latinate word with the plain English one wherever the plain one is true:

| instead of | write |
|---|---|
| commentators | early scholars, the classical scholars |
| intercession | speaking up for someone before God |
| accountability | answering for what you do |
| hypothetical | imagined, a case that never happened |
| intermediaries | go-betweens |
| lexicographers | early Arabic dictionary writers |
| substitution | putting one thing in place of another |
| grammatically | in the grammar of the sentence |
| establishes / affirms | shows, says, sets out |
| encompasses | covers, holds |
| manifestation | sign, showing |
| subsequent | later |
| utilise, employ | use |
| prior to | before |
| in order to | to |
| the manner in which | how |

Keep a technical word when it is the thing being taught and the note explains it — a `keyTerms` gloss can stay precise. Everywhere else, plain wins.

**Shape.** Lead with the point, then the support. Turn a nominalisation back into a verb ("the revelation of the surah occurred during" -> "the surah came down during"). Prefer active voice and concrete subjects: people, places, things, God. Cut throat-clearing at the start of a section.

# The targets

Measured by `Tools/content-gen/lib/readability.mjs` (Flesch-Kincaid grade, mean words per sentence). `node author.mjs rewrite-dir` refuses a body that misses them.

| field | grade | words per sentence | word count |
|---|---|---|---|
| meaning | 8.5 or lower | 20 or fewer | 45-105 |
| historicalContext | 9.5 or lower | 20 or fewer | 40-90 |
| lifeInProphetsTime | 8.5 or lower | 20 or fewer | 40-90 |
| didYouKnow | 9.5 or lower | 20 or fewer | 30-80 |
| theologicalSignificance | 8.5 or lower | 20 or fewer | 40-95 |
| applyIt | 8.5 or lower | 20 or fewer | 30-80 |
| explainEasier | 6 or lower | 20 or fewer | 25-50 |
| keyTerms[].gloss | — | — | 1-6 |
| keyTerms[].note | — | — | 15-45 |
| crossReferences[].why | — | — | 8-30 |

The word ranges are the same ones the note was written to, and they are enforced. A section that loses a fact to hit a grade has failed; a section that keeps every fact in shorter sentences has succeeded.

# The new field: `explainEasier`

25-50 words, grade 6 or lower: **what this passage is saying, as you would tell a twelve-year-old.** One or two short sentences. Say what the passage says, not what it is famous for and not what the reader should do about it. No Arabic, no names of scholars, no theological vocabulary. It is the line the reader taps when the note itself was still too much.

Good: "God is telling people that everything in the sky and on the earth belongs to him. Nothing happens without him knowing. He never gets tired of looking after it all."

Not: "This verse establishes the doctrine of divine omniscience and sovereignty." — that is the note again, in worse words.

# Output

Reply with a single JSON object and nothing else: no prose before it, no code fence, no commentary. It carries exactly these fields:

`theme`, `themeId`, `title`, `meaning`, `historicalContext`, `keyTerms`, `lifeInProphetsTime`, `didYouKnow`, `theologicalSignificance`, `crossReferences`, `applyIt`, `exploreFurther`, `explainEasier`

Do not write `key`, `surah`, `start`, `end`, `tier` or `meta`: the pipeline stamps those.
