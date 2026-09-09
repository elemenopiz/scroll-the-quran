# Deep Study authoring — brief for author agents

You are writing "Deep Study" commentary that ships to Muslim readers inside
Scroll the Quran. There is **no Anthropic API key** for this project, so the
Message Batches pipeline cannot run and you, an Opus agent in a Claude Code
session, are the model. Everything else in `Tools/content-gen` stays the source
of truth: the same system prompt, the same schema, the same validator, the same
assembler.

Read `Tools/content-gen/prompts/system.md` in full before you write anything.
This brief does not replace it.

## The one hard rule

**Never edit `out/study/surah_NNN.json` by hand.** Shards are generated. The only
path into them is:

```
author.mjs write  ->  work/cache/*.json  ->  author.mjs assemble  ->  out/study/*.json
```

Hand-editing a shard will be silently overwritten by the next `assemble`, and it
skips every validation rule.

## Setup

```bash
cd Tools/content-gen
npm install
npm test                        # must be green before you start
```

`work/` is gitignored, so a fresh checkout has no `work/units.jsonl`.
`author.mjs` rebuilds it from the committed `out/study/passages.json`
automatically. Do **not** run `node segment-passages.mjs` with no flags to fix
it: its defaults segment at 12 own-words and would replace the committed 3,293-unit
`passages.json` with a different 4,766-unit one. If you ever must regenerate,
pass `--min-own-words 24 --max-words 60`.

## Claim a slice

```bash
node author.mjs status                       # what is already done
node author.mjs todo --only discover --limit 40
node author.mjs todo --only surah:18
node author.mjs todo --only keys:2:255,18:10
```

`todo` lists only units with no cache record **and** no entry in the committed
shards, so parallel waves never collide. Take the slice from the top of the list
and tell the orchestrator which keys you claimed. Discover units come first;
they are the curated feed and are read most.

## The loop

For each key:

```bash
node author.mjs prompt 2:255            # read the passage in context
#   ...write the body to bodies/2_255.json...
node author.mjs write 2:255 bodies/2_255.json
```

Write bodies into a scratch directory as `<key>.json` with `_` for the `:`
(`2_255.json`, `2_153-157.json`), then validate a batch at once:

```bash
node author.mjs write-dir bodies/       # all-or-nothing
```

`write` and `write-dir` run the whole `validate.mjs` rule set before anything
touches the cache, including the near-duplicate check against every note already
written. Nothing is cached until the batch is clean. When your slice is done:

```bash
node author.mjs assemble
node validate.mjs out/study             # must exit 0
node author.mjs status                  # confirm the count
```

A body contains only the fields the model writes (`x-modelFields` in the
schema). `key`, `surah`, `start`, `end`, `tier` and `meta` are stamped by
`assemble`; if you leave them in the file they are dropped, but a `key` that
disagrees with the target is an error.

## Lessons from wave 1 (read these)
- **Never write to the scratchpad root** (`/private/tmp/claude-501/…/scratchpad/`): sibling authors overwrite each other's helper scripts there within minutes. Put helpers (`wc.mjs`, `show.mjs`, search scripts) under `Tools/content-gen/work/authoring/<your-branch>/` too.
- **Namespace your scratch.** The session scratchpad is shared by sibling authors. Keep key lists and bodies under `Tools/content-gen/work/authoring/<your-branch>/` (gitignored; the Write tool is allowed there, only `work/cache`, `work/requests`, `work/batches` are hook-protected), one fresh directory per batch — `write-dir` is all-or-nothing over a directory and will refuse a batch that contains an already-assembled body.
- **Run `node author.mjs status` before `npm test`** on a fresh worktree; it rebuilds `work/units.jsonl`. Never run `segment-passages.mjs`.
- **Word counts split on whitespace**, so a spaced em dash costs a word. `meaning` is now 45–105 words.
- **Four themes were added** (`divine-attributes`, `revelation-and-its-rejection`, `wealth-and-property`, `love-of-god`); spread themes across a slice, do not lean on one id.
- **Sectarian-sensitive occasions** (e.g. 28:56, 42:23): describe the setting generally and give classical readings side by side; never name figures whose status divides communities.
- **`didYouKnow`:** prefer checkable structural or lexical facts (phrase counts, grammatical forms, surah structure) over impressive claims you cannot verify.

## Quality bar

Structure is enforced by the validator. Truth is not. Take the time.

- **Grounded.** Mainstream classical tafsir — Ibn Kathir, al-Tabari,
  al-Qurtubi, al-Sa'di. Say what they broadly agree on. Where they genuinely
  differ, say so and give the range without picking a winner. If you are not
  confident something is attested, leave it out: a plainer section beats a wrong
  one.
- **Non-sectarian.** No school of law, no theological school, no movement, no
  framing of one group against another.
- **No legal rulings.** Describe what a passage has been understood to
  establish; never tell the reader what they are required to do. Passages that
  are legal in content (fasting, fighting, marriage, purity) are written
  descriptively and warmly, and `applyIt` turns toward attention or character
  rather than practice.
- **Occasions of revelation only when well attested.** Otherwise describe the
  Meccan or Medinan setting. Where reports differ, say they differ.
- **Honorific.** "the Prophet Muhammad (peace be upon him)" at the first naming,
  "the Prophet" after. Once per note — a second use is a warning.
- **Arabic script only in `keyTerms[].arabic`**, taken from the passage itself,
  with a faithful gloss and a note that says what the root or usage adds. Never
  a transliteration, never Arabic anywhere else, never "sabr (patience)" in
  prose.
- **Every cross-reference must be real and must genuinely relate.** Check the
  ayah number. `why` says how it connects, not what it says.
- **`applyIt` in warm second person**: one small, concrete, doable thing. Not a
  ruling, not generic advice, not a summary of the passage.
- **No filler.** Do not open a section by restating the verse. `didYouKnow` is a
  verifiable fact, not a moral.
- **Vary your prose.** The validator errors on near-duplicate `meaning` sections
  at 0.50 shingle overlap and warns at 0.35. Passages that resemble each other
  (charity ayat, the "no fear nor grief" refrain) need genuinely different
  angles, not different synonyms.

## Two exemplary bodies

### `2:255` — a famous passage

Written for a unit the reader already half knows. Nothing is paraphrased; the
note tells them what the structure is doing. The `keyTerms` note on
`كُرْسِيُّهُ` records the classical range rather than choosing, which is what
"scholars differ" looks like inside a 45-word field. `didYouKnow` uses a
well-known report and attributes it as a report. `applyIt` attaches the ayah to
a specific hour of the reader's day.

```json
{
  "theme": "Protection and Refuge",
  "themeId": "protection-and-refuge",
  "title": "The Living And The Sustaining",
  "meaning": "The ayah is built as a sequence of denials and possessions. God is alive and self-subsisting, so nothing external holds Him up. Neither drowsiness nor sleep touches Him, which rules out the lapse in attention every ruler and guardian eventually has. Everything belongs to Him, no one intercedes without leave, and human knowledge reaches nothing of His except what He allows. It closes by saying that holding the heavens and the earth does not tire Him.",
  "historicalContext": "Medinan, positioned between an appeal to spend before a day of no bargaining and the declaration that religion is not compelled. The classical commentators note the sequence rather than reporting a specific occasion for the ayah. Read in place, it supplies the reason the surrounding instructions carry weight: the one issuing them neither sleeps, nor forgets, nor tires.",
  "keyTerms": [
    {
      "arabic": "ٱلْقَيُّومُ",
      "gloss": "the Self-Subsisting, the Sustainer",
      "note": "An intensive form from the verb to stand. It joins two ideas the English needs two words for: standing without support, and holding everything else upright at the same time."
    },
    {
      "arabic": "سِنَةٌ",
      "gloss": "drowsiness",
      "note": "The state just before sleep, when attention slips but the eyes are open. Naming it separately from sleep closes the gap a listener might have left, since a watchman can nod without lying down."
    },
    {
      "arabic": "كُرْسِيُّهُ",
      "gloss": "His seat, His footstool",
      "note": "The classical commentators read it as His knowledge, His sovereignty, or a created thing beneath the greater Throne, and they record the range without insisting. All agree it implies no bodily sitting."
    }
  ],
  "lifeInProphetsTime": "Sleep was the vulnerability of that world. Caravans posted watches through the night, and a sentry who dozed could lose the whole company to a raid before dawn. A chief slept and his authority paused; a guardian slept and the herd was unguarded. Everyone listening had lain awake keeping watch or had trusted someone else to. Denying drowsiness to God was denying the one failure they most feared in a protector.",
  "didYouKnow": "The classical tradition preserves a report in which the Prophet Muhammad (peace be upon him) asked a companion which ayah of the Book he considered greatest, and accepted this one as the answer. It sits at number 255 of 286 in the longest surah, and it contains no command, no narrative and no address to a human being; it is entirely description.",
  "theologicalSignificance": "The ayah defines God largely by removing limits rather than by attributing qualities, which keeps the description from resolving into a picture. Intercession is admitted but placed entirely under permission, which preserves both hope and sovereignty. And the final clause answers a specific human intuition, that sustaining something enormous must cost something, by denying that any effort is involved at all.",
  "crossReferences": [
    {
      "ref": "3:2",
      "why": "Opens with the same two names, the Living and the Sustaining, at the head of another surah."
    },
    {
      "ref": "112:1-4",
      "why": "Defines God by denial in the same way, at the shortest possible length."
    },
    {
      "ref": "6:59",
      "why": "Expands the theme of knowledge that reaches everything, down to a falling leaf."
    }
  ],
  "applyIt": "Say this ayah once tonight before you sleep, and let the line about drowsiness land on your own tiredness. You are about to stop paying attention for eight hours, and something you have no part in will keep running. Most people find that the ayah works differently at that hour than at any other. Try it at the point where you are least capable.",
  "exploreFurther": [
    "3:2",
    "6:59",
    "59:22-24"
  ]
}
```

### `2:216` — a hard passage

Written for a unit that is uncomfortable and easy to get wrong. It stays
descriptive about fighting, gives the historical situation honestly (including
the community's reluctance), and lets the general principle carry the note. Note
the `keyTerm` on `عَسَىٰٓ`: the particle of possibility is what keeps the
passage from becoming a claim that all suffering is secretly good, and saying so
protects a grieving reader. `applyIt` asks for accuracy about the past rather
than for a feeling.

```json
{
  "theme": "Trust in God",
  "themeId": "trust-in-god",
  "title": "You Do Not Know What Is Good",
  "meaning": "A hard instruction is given and the dislike it will provoke is acknowledged in the same breath. Then the sentence widens into a general principle that reaches far past its occasion: you may hate what is good for you and love what harms you. The final clause explains why, and it is not a comfort about outcomes. It is a statement about the limits of human knowledge, which is left as the last word.",
  "historicalContext": "Medinan, from the period when the community in Medina faced organised hostility from Mecca and was being told to defend itself, having been forbidden to fight during the Meccan years. The commentators describe genuine reluctance among believers, some of it moral and some of it fear, and read the opening concession as taking that reluctance seriously rather than dismissing it. The ayat that follow address specific questions arising from the same conflict.",
  "keyTerms": [
    {
      "arabic": "كُرْهٌ",
      "gloss": "an aversion, a hated thing",
      "note": "Not mild dislike. The word covers what is repugnant and imposed against inclination, and the Quran uses it here of the believers themselves, conceding their feeling rather than criticising it."
    },
    {
      "arabic": "عَسَىٰٓ",
      "gloss": "it may be that",
      "note": "A particle of hope and possibility. It keeps the two clauses that follow from becoming a rule, so the passage says this can happen rather than that every dislike conceals a benefit."
    },
    {
      "arabic": "خَيْرٌ",
      "gloss": "good, better",
      "note": "The comparative and the plain adjective share a form, so the word slides between good and better. What is being contrasted is not pleasure and pain but two assessments of the same thing."
    }
  ],
  "lifeInProphetsTime": "The emigrants in Medina had left houses, businesses and family behind and arrived dependent on hosts. Conflict with Mecca threatened the caravan trade that many of them still had relatives working in, and fighting meant facing cousins and brothers across a field. Reluctance in that setting was not squeamishness. It was the reasonable response of people who could name, individually, the men they might meet.",
  "didYouKnow": "The two central clauses of this ayah are among the most widely quoted lines in Arabic outside religious contexts, used as ordinary consolation after a lost job or a failed engagement. The classical commentators already treated the principle as detachable from the occasion, which is why the generalisation is phrased with a particle of possibility rather than as a claim about every case.",
  "theologicalSignificance": "The passage locates the gap between God and the human being in knowledge rather than in power, which is a specific claim. It does not say that everything painful turns out well, only that your evaluation is made with less information than you assume. That leaves room for grief to be real while judgement is suspended. And by admitting the aversion first, it models a faith that does not require pretending to want what you do not want.",
  "crossReferences": [
    {
      "ref": "4:19",
      "why": "Applies the same principle to marriage: you may dislike something in which God places much good."
    },
    {
      "ref": "18:65-82",
      "why": "Dramatises the point at length, three acts that look wrong until their reasons are given."
    },
    {
      "ref": "12:87",
      "why": "Shows Jacob holding hope against every visible sign, and refusing to despair of God's relief."
    }
  ],
  "applyIt": "Think of something from five years ago that you did not want and now would not undo. Write down one sentence about it. Then think of something you are resisting now and put the two beside each other, without concluding anything. The point is not to talk yourself into liking it. It is to remember, accurately, that your reading of events has been wrong before.",
  "exploreFurther": [
    "4:19",
    "18:65-82",
    "12:87"
  ]
}
```

## Common validation failures and how to fix them

| Message | Fix |
| --- | --- |
| `meaning is 97 words, must be 45-95` | Cut a clause, not a sentence. Bounds come from `x-wordBounds` in the schema and are not negotiable. |
| `keyTerms[].gloss is 7 words, must be 1-6` | Glosses are 1-6 words. Move the nuance into `note`. |
| `keyTerms[0].arabic is not Arabic script` | You wrote a transliteration. Copy the word from the `### Arabic (Uthmani)` block in the prompt. |
| `meaning contains Arabic script` | Arabic belongs in `keyTerms[].arabic` only, including in `why`, `gloss` and `note`. |
| `crossReferences[0].ref out of bounds: 112:9` | The ayah does not exist. Check the surah's ayah count before citing. |
| `use "God" in English prose` | The app ships an English translation that says God. Never "Allah" in prose. |
| `prescriptive ruling` / `legal ruling language` | You wrote "you must", "it is forbidden", or similar. Rewrite descriptively. |
| `sectarian framing` / `school-of-law framing` | A school or sect was named. Remove it; state the common ground instead. |
| `names Muhammad without the honorific` | The first naming across all prose fields carries "(peace be upon him)". |
| `unknown themeId` | Ids come from `out/themes.json`, used verbatim, with the matching title in `theme`. |
| `key is not a unit key` | Use the unit key from `todo`, not a bare ayah reference. |
| `meaning is a near-duplicate of X` | Two notes are saying the same thing. Find a different angle for one of them. |
| `WARN honorific used more than once` | Second and later mentions are "the Prophet". |
| `WARN … points at the passage itself` | A cross-reference or `exploreFurther` entry is the unit's own key. |

## Commit conventions

Commit the content, not `work/` (it is gitignored). A wave is:

```bash
git add Tools/content-gen/out/study Tools/content-gen/out/discover.json
git commit -m "content: Deep Study notes for <slice>" \
           -m "..." \
           -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Every commit carries the trailer `Co-Authored-By: Claude Fable 5.1
<noreply@anthropic.com>`. Say in the message which keys the wave covers and
paste the `validate.mjs out/study` result. Do not merge; the orchestrator
integrates.

Note that `assemble` restamps `generatedAt` on every shard it writes, so
re-running it touches surahs you did not author. Commit only the shards your
slice actually changed unless the orchestrator asks otherwise.

## Definition of done for a wave

- `npm test` green
- `node author.mjs write-dir` clean for every body in the slice
- `node author.mjs assemble` run
- `node validate.mjs out/study` exits 0
- `node author.mjs status` shows the new count
- shards committed with the trailer, `work/` untouched by git
