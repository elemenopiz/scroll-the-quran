# Bundled Quran data — sources and licences

Everything in `Content/quran/` is generated:

- `surahs.json` and `itani.json` by `Tools/content-gen/ingest-quran-data.mjs`
- `arabic-uthmani.json`, `saheeh.json`, `ruwwad.json`, `pickthall.json` and
  `translations.json` by `Tools/content-gen/sync-quran-content.mjs`

Edit the generators, not the JSON. Every flat array holds exactly 6,236 strings, indexed
`surah.startIndex + ayah - 1`, so `2:255` is index 261.

Fetched 2026-09-09.

## Structure — `surahs.json`

Surah numbers, names, ayah counts, revelation type and place, ruku counts and juz
boundaries are derived from **Tanzil quran-data.xml**.

- Source: <https://tanzil.net/res/text/metadata/quran-data.xml>
- Copyright: (C) 2008-2009 Tanzil.info
- Licence: **Creative Commons Attribution 3.0 (CC BY 3.0)**
- Required notice: "Quran metadata from Tanzil.net, licensed CC BY 3.0."

The English transliterations of the surah names in `Tools/content-gen/surah-names.mjs`
are ours; Tanzil's own `ename` values are carried through as the `meaning` field.

## Arabic text — `arabic-uthmani.json`

The Uthmani (Hafs) rasm shown as the muted Arabic layer above every English verse.

- Upstream source: **Tanzil.net**, Uthmani text (`quranType=uthmani`)
- Copy used: <https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranuthmanihaf.json>,
  a verbatim mirror of the Tanzil Uthmani Hafs text. The generator falls back to
  `POST https://tanzil.net/pub/download/download.php` with
  `quranType=uthmani&outType=txt&agree=true` when the mirror is unreachable.
- Copyright: (C) 2007-2025 Tanzil.net
- Licence: **Creative Commons Attribution 3.0 (CC BY 3.0)**
- Required notice, shown verbatim in the app's Translation sheet:
  **"Quran text (Uthmani) from Tanzil.net, licensed CC BY 3.0."**

Stored verbatim including pause marks and superscript vowels; only surrounding
whitespace is normalised. Tanzil's licence forbids altering the text.

## Translations

All four are bundled and read offline. Copyright and attribution strings live in
`translations.json` and are rendered verbatim in the Translation sheet.

### `itani.json` — default

- Translator: **Talal Itani**, *ClearQuran*
- Source of this copy: <https://github.com/fawazahmed0/quran-api> edition `eng-talalitani`
- Licence: **Creative Commons Attribution-NoDerivatives 4.0 (CC BY-ND 4.0)**, commercial
  use permitted, no modification permitted
- Required notice: **"Translation by Talal Itani, ClearQuran.com"**

### `saheeh.json`

- Translation: **Saheeh International**, *The Qur'an: English Meanings*
- Source of this copy: <https://quranenc.com/api/v1/translation/sura/english_saheeh/{1..114}>
  (QuranEnc key `english_saheeh`, version recorded in `translations.json`)
- Terms: verbatim republication with attribution
- Required notice: **"Saheeh International, via QuranEnc.com"** plus the version string

### `ruwwad.json`

- Translation: **Ruwwad Translation Center**, with the Islamic University of Madinah,
  the Rabwah Dawah Association and IslamHouse.com
- Source of this copy: <https://quranenc.com/api/v1/translation/sura/english_rwwad/{1..114}>
  (QuranEnc key `english_rwwad`, version recorded in `translations.json`)
- Terms: verbatim republication with attribution
- Required notice: **"Ruwwad Translation Center, via QuranEnc.com"** plus the version string

### `pickthall.json`

- Translation: **Marmaduke Pickthall**, *The Meaning of the Glorious Koran* (1930)
- Source of this copy: <https://github.com/fawazahmed0/quran-api> edition `eng-mohammedmarmadu`
- Licence: **public domain**

## What the generator changes

- Runs of whitespace are collapsed to a single space and the ends are trimmed.
- QuranEnc marks footnotes inline as `[1]`, `[2]`, … and occasionally wraps text in HTML.
  Those markers and tags are removed and the footnote bodies are not ingested; no word of
  the translation itself is altered.
- QuranEnc writes honorifics as Arabic presentation-form ligatures. They are spelled out in
  English (`ﷺ` → "(peace and blessings be upon him)") so that no translation entry carries
  Arabic script.

Nothing else is touched. `sync-quran-content.mjs --verify` re-checks from disk that every
translation file has 6,236 non-empty entries with **no** Arabic script, that
`arabic-uthmani.json` has 6,236 entries that **all** contain Arabic script, and that
`translations.json` names exactly one default with unique abbreviations and existing files.

## Arabic is a design layer, not the reading text

English is the reading text; the Arabic Uthmani line sits above it, muted and RTL
(`CLAUDE.md` rule 5). The app never transliterates: where an Arabic term is named, it is
shown in Arabic script with an English gloss.
