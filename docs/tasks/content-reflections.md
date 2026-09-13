# Content — Reflection cards for the Discover feed (owner, 2026-09-13)
Worktree: `git worktree add ../scroll-the-quran-reflections -b content/reflections` from `main`. No simulator. Owns: `Tools/content-gen/reflections/**` (new), `Tools/content-gen/build-reflections.mjs` (new), `Tools/content-gen/validate.mjs` (a `reflections` sub-command only), `Content/reflections.json` (generated), `Packages/ScrollKit/Sources/StudyContent/Reflections.swift` (new model + loader), `Packages/ScrollKit/Tests/StudyContentTests/ReflectionsTests.swift`, `Tools/content-gen/ATTRIBUTION.md` (a Reflections section), `docs/content/reflections.md` (the editorial rules below, kept as the living spec). The Discover UI for the card is a separate task (Phase 4o) that reads your model.

The original app's Discover feed interleaves quote cards labelled REFLECTION: a quote in serif, an attribution line ("— Augustine of Hippo"), no verse, no study. Ours needs the Islamic equivalent, and the bar for authenticity is the same as the study notes: **never invent, never misattribute.** Every entry ships with a source the owner can check.

## Editorial rules (write them into docs/content/reflections.md)
1. Admissible sources, in order of preference:
   - Hadith of the Prophet Muhammad (peace be upon him) from Sahih al-Bukhari, Sahih Muslim, or Riyad al-Salihin / al-Arba'in al-Nawawiyya, cited by collection and number (e.g. "Sahih Muslim 2699"). Your own concise English rendering (no copying a copyrighted translation); keep it under 40 words.
   - Sayings of the Companions and early Muslims with a named classical source work (e.g. Ali ibn Abi Talib in Nahj al-Balagha; Umar, Abu Bakr, Hasan al-Basri via Abu Nu'aym's Hilyat al-Awliya or Ibn al-Jawzi).
   - Classical scholars and sages with a named work: al-Ghazali (Ihya Ulum al-Din, Ayyuha al-Walad), Ibn al-Qayyim (Madarij al-Salikin, al-Fawa'id), Ibn Ata'illah (al-Hikam), Rumi (Masnavi, Fihi Ma Fihi), Ibn Hazm, al-Nawawi, Ibn Taymiyya only where non-polemical, Rabia al-Adawiyya, Malik ibn Dinar, Ibn al-Mubarak.
   - Short Quranic-adjacent prayers of the Prophet (du'a) are welcome; Quranic verses are NOT reflections (the feed already carries them).
2. Excluded: anything whose attribution is folk ("attributed to", internet-famous with no source), sectarian polemic, legal rulings, anything about other faiths, and living authors (copyright).
3. Non-sectarian: nothing that only one school or community accepts; Nahj al-Balagha and Sahih al-Bukhari sit side by side.
4. Tone: warm, direct, about God, the heart, patience, gratitude, mercy, death and remembrance, knowledge, character, kindness. 10–45 words each. English only in `text` (rule 4 of the study prompt: no transliteration in parentheses; an Arabic term may go in an optional `arabic` field for a later muted line).
5. Attribution string exactly as the card prints it: "Prophet Muhammad ﷺ" is NOT used — print "The Prophet Muhammad (peace be upon him)" for hadith, otherwise the common English name ("Ali ibn Abi Talib", "Al-Ghazali", "Ibn al-Qayyim", "Rumi", "Rabia al-Adawiyya").
6. Each entry: `{ id, text, attribution, source: {work, locator, translator: "own"}, arabic?: string, themes: [themeId…] (from Content/themes.json), confidence: "high"|"medium" }`. Only `high` ships; `medium` stays in the catalogue behind a flag so the owner can promote it.

## Deliver
1. `Tools/content-gen/reflections/catalogue.mjs`: **at least 120** entries meeting the rules, at least 40 hadith, at least 30 from the Companions/early generations, the rest classical scholars; no more than 12 from any one person; every theme in `themes.json` covered by at least 3 entries.
2. `build-reflections.mjs` → `Content/reflections.json` `{version, generatedAt: fixed string, count, items}` deterministic (run twice, empty diff), `validate.mjs reflections` enforcing the shape, word counts, uniqueness of text, and that every `themes[]` id exists.
3. **Second-pass verification inside your run:** after writing the catalogue, re-read every entry cold and drop or downgrade to `medium` anything you cannot place in the cited work. Report how many survived at `high`.
4. Swift: `Reflection` (Codable, Sendable, Identifiable) + `ReflectionsFile` + `ReflectionStore` loading from `Content/reflections.json` through the existing `StudyContentLoading` bundle path (see `DiscoverFeed.init(loader:path:)`), with a deterministic `items(seed:)` order like `DiscoverFeed`. Tests: file decodes, count ≥ 120, ids unique, every theme resolves.
5. ATTRIBUTION.md: the works cited and the statement that renderings are the app's own.
6. Gate: `node Tools/content-gen/validate.mjs reflections`, `cd Packages/ScrollKit && swift test --filter StudyContentTests`, `Tools/verify.sh --skip-sim` PASS. Merge into main with `--no-ff`, remove the worktree.
Report: counts by source class, the per-person maximum, the `medium` list, and anything you could not source.
