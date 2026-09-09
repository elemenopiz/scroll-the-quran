# Content attribution — Scroll the Quran

Every text, translation and font bundled with the app, with its upstream source, licence
and the date it was fetched. Regenerate the data with
`node Tools/content-gen/ingest-translations.mjs --fetch` and the fonts with
`node Tools/content-gen/ingest-fonts.mjs --fetch`; re-validate with
`node Tools/content-gen/ingest-translations.mjs --verify`.

All ingests below were performed on **2026-09-09 (UTC)**.
Raw upstream responses are cached under `Tools/content-gen/work/raw/` (gitignored);
the committed artefacts live in `Tools/content-gen/out/`.

---

## 1. Arabic Quran text — `out/quran/arabic-uthmani.json`

| | |
|---|---|
| Source | **Tanzil Project** — Tanzil Quran Text (Uthmani, Version 1.1) |
| URL | `https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=txt-2&marks=true&sajdah=true&alef=true&tatweel=true&agree=true` |
| Project home | https://tanzil.net/ — licence terms at https://tanzil.net/docs/Text_License |
| Licence | **Creative Commons Attribution 3.0** (CC BY 3.0) |
| Copyright | Copyright © 2007–2026 Tanzil Project |
| Fetched | 2026-09-09 |
| Fallback (not used) | `https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranuthmanihaf.json` |

Download options used: Uthmani text type, "Text (with aya numbers)" output, with pause
marks, sajdah signs, superscript alef and tatweel **kept** (`marks`, `sajdah`, `alef`,
`tatweel` all on). Rub-el-hizb marks, and the "laa"/"stanween" simplifications, are off.

The text is stored **verbatim** — no normalisation, no stripping of pause marks. The
Tanzil copyright block shipped with the download is reproduced here in full, as its terms
require:

> PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK
>
> Tanzil Quran Text (Uthmani, Version 1.1)
> Copyright (C) 2007-2026 Tanzil Project
> License: Creative Commons Attribution 3.0
>
> This copy of the Quran text is carefully produced, highly verified and continuously
> monitored by a group of specialists at Tanzil Project.
>
> TERMS OF USE:
>
> - Permission is granted to copy and distribute verbatim copies of this text, but
>   CHANGING IT IS NOT ALLOWED.
>
> - This Quran text can be used in any website or application, provided that its source
>   (Tanzil Project) is clearly indicated, and a link is made to tanzil.net to enable
>   users to keep track of changes.
>
> - This copyright notice shall be included in all verbatim copies of the text, and shall
>   be reproduced appropriately in all files derived from or containing substantial
>   portion of this text.
>
> Please check updates at: http://tanzil.net/updates/

**In-app attribution (required):** "Quran text: Tanzil Project (tanzil.net), CC BY 3.0",
with a live link to https://tanzil.net/.

> **Note for the reader UI.** In Tanzil's Uthmani text the *basmala* is part of ayah 1 of
> every surah except 1 (where it is ayah 1 in its own right) and 9 (which has none), so
> `arabic-uthmani.json[startIndex]` for surahs 2–114 begins with
> `بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ ` while the English translations do not. The text is kept verbatim
> here because Tanzil's terms forbid changing it; presentation (showing the basmala as a
> surah header rather than inline in ayah 1) is a UI decision.

---

## 2. Quran metadata — `out/quran/surahs.json`

| | |
|---|---|
| Source | **Tanzil Project** — Quran metadata (`quran-data.xml`, version 1.0) |
| URL | https://tanzil.net/res/text/metadata/quran-data.xml |
| Docs | https://tanzil.net/docs/Quran_Metadata |
| Licence | **Creative Commons Attribution 3.0** (CC BY 3.0) |
| Copyright | Copyright © 2008–2009 Tanzil.info |
| Fetched | 2026-09-09 |

Derived fields: `number`/`ayahCount`/`startIndex` from `<sura index ayas start>`;
`name` from `tname` (Latin surah name), `meaning` from `ename`; `revelation` from
`type` (`Meccan` → `makki`, `Medinan` → `madani`); `juz` from the 30 `<juz>` markers and
`pages` from the 604 `<page>` markers, expanded to every unit overlapping the surah.

---

## 3. English translations

### 3.1 Talal Itani — ClearQuran (default) — `out/quran/itani.json`

| | |
|---|---|
| Translator | Talal Itani |
| Edition | *Quran in English — Clear and Easy to Read*, ClearQuran.com |
| Source | fawazahmed0/quran-api v1, edition `eng-talalitani` |
| URL | https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-talalitani.json |
| Upstream repo | https://github.com/fawazahmed0/quran-api (aggregator; the API itself is Unlicense) |
| Licence | **CC BY-ND 4.0** |
| Fetched | 2026-09-09 |
| Attribution string (verbatim, shown in the Translation sheet) | `Translation by Talal Itani, ClearQuran.com` |

CC BY-ND forbids derivatives, so this text is shipped **unmodified**.

### 3.2 Saheeh International — `out/quran/saheeh.json`

| | |
|---|---|
| Translator | Saheeh International |
| Source | **QuranEnc.com** (Encyclopedia of the Noble Qur'an), key `english_saheeh`, listed there as "English Translation - Noor International Center" |
| URL | `https://quranenc.com/api/v1/translation/sura/english_saheeh/{1..114}` |
| Text version | **1.1.2** (reported by https://quranenc.com/api/v1/translations/list) |
| Licence | Free redistribution permitted by the publisher through QuranEnc.com; no SPDX licence is stated. QuranEnc describes itself as "a portal featuring free and trustworthy translations … accessible and shareable". |
| Fetched | 2026-09-09 |
| Attribution string (verbatim) | `Saheeh International, via QuranEnc.com` |

Normalisation applied to the `translation` field (`arabic_text` and `footnotes` are not
shipped): numeric footnote markers (`[2]`, `(1)`) removed, HTML tags/entities resolved,
whitespace collapsed. Saheeh's bracketed interpolations (`[of]`, `[i.e., …]`) are kept.
The Arabic honorific ligature ﷺ (U+FDFA), which appears in 34 verses as `(ﷺ)`, is removed
along with its parentheses so that no translation entry contains Arabic script — in this
app Arabic is a separate, muted design layer and never appears inside the English line.

### 3.3 Ruwwad Translation Center — `out/quran/ruwwad.json`

| | |
|---|---|
| Translator | Ruwwad (Rowwad) Translation Center, with the Rabwah Dawah Association and IslamHouse.com |
| Source | **QuranEnc.com**, key `english_rwwad` |
| URL | `https://quranenc.com/api/v1/translation/sura/english_rwwad/{1..114}` |
| Text version | **1.0.19** |
| Licence | Free redistribution permitted by the publisher through QuranEnc.com; no SPDX licence stated. |
| Fetched | 2026-09-09 |
| Attribution string (verbatim) | `Ruwwad Translation Center, via QuranEnc.com` |

Same normalisation as 3.2.

### 3.4 Marmaduke Pickthall — `out/quran/pickthall.json`

| | |
|---|---|
| Translator | Marmaduke Pickthall |
| Edition | *The Meaning of the Glorious Koran* (1930) |
| Source | fawazahmed0/quran-api v1, edition `eng-mohammedmarmadu` |
| URL | https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mohammedmarmadu.json |
| Licence | **Public domain** (published 1930; copyright expired) |
| Fetched | 2026-09-09 |

---

## 4. Fonts — `out/fonts/`

### 4.1 KFGQPC Uthmanic Hafs v18 (primary Arabic face)

| | |
|---|---|
| File | `UthmanicHafs1Ver18.ttf` (242,368 bytes) |
| Family name | **KFGQPC HAFS Uthmanic Script** |
| Full name | KFGQPC HAFS Uthmanic Script Regular |
| PostScript name | **KFGQPCHAFSUthmanicScript-Regula** |
| Version string | Version 0.18 |
| URL | https://verses.quran.foundation/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.ttf |
| Mirror | https://github.com/nuqayah/qpc-fonts |
| Copyright | © 2010 King Fahd Glorious Quran Printing Complex (KFGQPC), Al-Madinah Al-Munawwarah. ISBN 978-603-8010-15-0, Accession No. 1430/7278. |
| Licence | KFGQPC electronic end-user licence: use, copy and distribute permitted free of cost; **selling, modifying, altering, reverse-engineering the font is not permitted**. Full text in `out/fonts/UthmanicHafs1Ver18-LICENSE.txt`. |
| Fetched | 2026-09-09 |

KFGQPC publishes no standalone licence file, so `UthmanicHafs1Ver18-LICENSE.txt` is
extracted verbatim from the font's own `name` table (name ID 0 = copyright notice,
name ID 13 = licence description) by `ingest-fonts.mjs`.

The font is bundled **unmodified** (no subsetting), as its licence requires.
It covers all 69 distinct code points used by `arabic-uthmani.json`.

### 4.2 Amiri 1.003 (fallback Arabic face)

| | |
|---|---|
| Files | `Amiri-Regular.ttf` (437,780 bytes), `Amiri-Bold.ttf` (414,560 bytes) |
| Family name | **Amiri** |
| PostScript names | **Amiri-Regular**, **Amiri-Bold** |
| Version string | Version 1.003 |
| URL | https://github.com/aliftype/amiri/releases/download/1.003/Amiri-1.003.zip |
| Project home | https://github.com/aliftype/amiri |
| Copyright | © 2010–2025 Khaled Hosny and the Amiri project authors |
| Licence | **SIL Open Font License 1.1** — full text in `out/fonts/OFL.txt` |
| Fetched | 2026-09-09 |

Amiri also covers all 69 code points used by `arabic-uthmani.json`.

---

## 5. Where these strings surface in the app

| Surface | Must show |
|---|---|
| Translation sheet | the selected translation's `copyright` and `attribution` from `translations.json`, verbatim |
| Settings / About | "Quran text: Tanzil Project (tanzil.net), CC BY 3.0" with a link to tanzil.net |
| Settings / About | "Arabic type: KFGQPC Uthmanic Hafs, © King Fahd Glorious Quran Printing Complex" and "Amiri, SIL OFL 1.1" |
| Share cards / widgets | translation `abbrev` (e.g. `CLEAR`) is sufficient; the full attribution stays in the Translation sheet |
