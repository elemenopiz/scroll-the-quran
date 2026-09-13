# Deep Study voice (owner-approved 2026-09-13)

The owner's brief: "We want people to be engaged with the text verse by verse. Not missing context, stunned by big/unknown words, and leaving with nothing." The first plain-language pass (`meta.simplified: "p1"`) lowered the reading level but kept the analytical voice ("three statements, each narrowing the last"). The voice pass (`"v2"`, `Tools/content-gen/lib/voice.mjs`) replaces it.

The standard lives in `Tools/content-gen/prompts/simplify.md`, which every rewrite agent is handed. The approved samples (2:255, 3:185, 12:4) are the reference: the note talks to the reader about the verse, opens on the human situation, gives context as a scene, leads did-you-know with the surprise, answers "what does this tell me about God and about me", and keeps a varied rhythm. Facts, hedges, word ranges and reading-level ceilings are unchanged from pass one.

Enforced by `validate.mjs` on units stamped `v2`: no structure-talk phrases in the reader-facing sections, no three fragments in a row, no section with more than 40 % fragments or under 9 words per sentence on average, plus the pass-one grade ceilings and the `explainEasier` bounds.
