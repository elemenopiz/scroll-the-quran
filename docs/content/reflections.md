# Reflection cards — editorial rules

The Discover feed interleaves **REFLECTION** cards among the verse cards: a saying in serif,
an attribution line underneath, no verse and no study sheet. This file is the living spec for
what may go on one. The catalogue is `Tools/content-gen/reflections/catalogue.mjs`; the build
script is `Tools/content-gen/build-reflections.mjs`; the gate is
`node Tools/content-gen/validate.mjs reflections`.

The bar is the same as the study notes: **never invent, never misattribute.** Every entry
ships with a source the owner can check. When in doubt, the entry is downgraded, not softened.

## 1. Admissible sources, in order of preference

1. **Hadith of the Prophet Muhammad (peace be upon him)** from Sahih al-Bukhari, Sahih Muslim,
   Riyad al-Salihin, or al-Arba'in al-Nawawiyya, cited by collection and number
   (`Sahih Muslim 2699`). Hadith qudsi are hadith: the attribution stays with the Prophet, who
   reports them, and the text says "God says".
2. **Sayings of the Companions and the early generations** with a named classical source work:
   Ali ibn Abi Talib in *Nahj al-Balagha*; Abu Bakr, Umar, Ibn Umar, Hasan al-Basri,
   Malik ibn Dinar, Ibn al-Mubarak via Abu Nu'aym's *Hilyat al-Awliya*, Ibn al-Jawzi's
   *Sifat al-Safwa*, Ibn al-Mubarak's *Kitab al-Zuhd*, Ibn Rajab's *Jami al-Ulum wa'l-Hikam*,
   or — best of all — a Companion's own words recorded inside Bukhari or Muslim.
3. **Classical scholars and sages** with a named work: al-Ghazali (*Ihya Ulum al-Din*,
   *Ayyuha al-Walad*), Ibn al-Qayyim (*Madarij al-Salikin*, *al-Fawa'id*), Ibn Ata'illah
   (*al-Hikam*), Rumi (*Masnavi*, *Fihi Ma Fihi*), Rabia al-Adawiyya (via Attar's
   *Tadhkirat al-Awliya*), al-Nawawi, Ibn Hazm.
4. **Short supplications of the Prophet** are welcome. **Quranic verses are not reflections** —
   the feed already carries them, and a reflection card has no verse line at all.

## 2. Excluded

Folk attribution ("attributed to", internet-famous with no traceable source — the "wound is
where the light enters you" class), sectarian polemic, legal rulings, anything about other
faiths or comparing them, and living authors (copyright).

## 3. Non-sectarian

Nothing that only one school or community accepts. *Nahj al-Balagha* and *Sahih al-Bukhari*
sit side by side, and neither is labelled.

## 4. Tone and prose

Warm, direct, unhurried. About God, the heart, patience, gratitude, mercy, death and
remembrance, knowledge, character, kindness. **10–45 words.** English only in `text`: no
transliterated Arabic in parentheses (the study prompt's rule 4), "God" and never the Arabic
name, no exclamation marks, no second-person preaching, no ruling language. An Arabic term
central to the saying may go in the optional `arabic` field, in Arabic script, for the muted
line the card may draw later.

## 5. Translation

**Every rendering is the app's own**, made concisely from the Arabic or Persian. No published
translation is copied, quoted or paraphrased closely — that is both a copyright rule and an
editorial one, because a card has to be shorter than any scholarly rendering. `translator` is
therefore always `"own"`, and `build-reflections.mjs` writes it rather than the catalogue.

## 6. Attribution string

Printed by the card verbatim. `"Prophet Muhammad ﷺ"` is **not** used: hadith print
**"The Prophet Muhammad (peace be upon him)"**. Everyone else gets the common English name —
"Ali ibn Abi Talib", "Al-Ghazali", "Ibn al-Qayyim", "Ibn Ata'illah", "Rumi",
"Rabia al-Adawiyya", "Al-Hasan al-Basri".

## 7. Shape

```js
{
  id, text, attribution,
  class: HADITH | EARLY | CLASSICAL,
  source: { work, locator },          // translator: "own" is added by the build script
  arabic?: "…",                        // Arabic script only, one term
  themes: [themeId, …],                // ids from Content/themes.json
  confidence: "high" | "medium",
}
```

## 8. Confidence

`confidence` is about **placement**: can this saying be placed in the cited work, by someone
checking? `high` means yes. Anything else is `medium`.

* **Only `high` ships.** `build-reflections.mjs` writes `high` entries into
  `Content/reflections.json`; `medium` stays in the catalogue for the owner to promote after
  checking, and is listed in the build's summary.
* Locator granularity follows the same honesty rule: a canonical number where the number is
  certain (`Sahih Muslim 2699`), otherwise the book or chapter of the work
  (`Riyad al-Salihin, chapter on certainty and reliance on God`). A vague locator is not a
  reason to downgrade; an uncertain *placement* is.
* Every entry is re-read cold after the catalogue is written, and anything that cannot be
  placed is downgraded then.

## 9. Quotas the build enforces

| Rule | Value |
|---|---|
| Entries shipped at `high` | ≥ 120 |
| Hadith | ≥ 40 |
| Companions and early generations | ≥ 30 |
| Per-person maximum | 12 |
| Themes in `Content/themes.json` covered | every one, ≥ 3 entries each |
| Word count | 10–45 |
| `text` unique | no two entries share a rendering |

The per-person maximum does **not** apply to the Prophet: the hadith floor is 40, so the cap
would contradict it. It applies to every other `attribution` string, which is what "one
person" means for a card that prints exactly that line.
