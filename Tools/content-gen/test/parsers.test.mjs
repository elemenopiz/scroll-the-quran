// Unit tests for the ingest parsers. Plain `node --test`, tiny hand-written
// fixtures only - nothing here touches the network or out/.

import test from "node:test";
import assert from "node:assert/strict";

import {
  parseTanzilText,
  extractTanzilCopyright,
  parseFawazEdition,
  parseQuranEncSura,
  cleanTranslation,
  parseQuranMetadata,
  buildSurahs,
} from "../lib/parsers.mjs";
import { flattenCanonical, hasArabic, arabicChars, TOTAL_AYAHS, CANONICAL_AYAH_COUNTS } from "../lib/quran.mjs";
import { buildRegistry, REGISTRY_FIELDS, REQUIRED_STRINGS } from "../lib/registry.mjs";

/* -------------------------------------------------------------------------- */

const TANZIL_FIXTURE = [
  "# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK",
  "#  Tanzil Quran Text (Uthmani, Version 1.1)",
  "#  License: Creative Commons Attribution 3.0",
  "",
  "1|1|بِسْمِ ٱللَّهِ",
  "1|2|ٱلْحَمْدُ لِلَّهِ ",
  "2|1|الٓمٓ",
  "",
  "#====================",
].join("\n");

test("parseTanzilText reads sura|aya|text lines and skips comments", () => {
  const rows = parseTanzilText(TANZIL_FIXTURE);
  assert.equal(rows.length, 3);
  assert.deepEqual(rows[0], { surah: 1, ayah: 1, text: "بِسْمِ ٱللَّهِ" });
  assert.equal(rows[1].text, "ٱلْحَمْدُ لِلَّهِ", "trailing whitespace is trimmed");
  assert.deepEqual(rows[2], { surah: 2, ayah: 1, text: "الٓمٓ" });
});

test("parseTanzilText keeps a pipe inside the verse text", () => {
  const rows = parseTanzilText("3|4|a|b");
  assert.equal(rows[0].text, "a|b");
});

test("parseTanzilText rejects an HTML error page", () => {
  assert.throws(() => parseTanzilText("<!DOCTYPE html>\n<html><body>404</body></html>"), /not "sura\|aya\|text"|no verse lines/);
});

test("parseTanzilText rejects an empty verse", () => {
  assert.throws(() => parseTanzilText("1|1|   "), /empty text/);
});

test("extractTanzilCopyright returns the comment block without markers", () => {
  const block = extractTanzilCopyright(TANZIL_FIXTURE);
  assert.match(block, /Tanzil Quran Text \(Uthmani, Version 1\.1\)/);
  assert.match(block, /Creative Commons Attribution 3\.0/);
  assert.ok(!block.includes("#"));
});

/* -------------------------------------------------------------------------- */

test("parseFawazEdition maps chapter/verse to surah/ayah", () => {
  const rows = parseFawazEdition({
    quran: [
      { chapter: 1, verse: 1, text: "In the name of God" },
      { chapter: 1, verse: 2, text: " Praise be to God " },
    ],
  });
  assert.deepEqual(rows, [
    { surah: 1, ayah: 1, text: "In the name of God" },
    { surah: 1, ayah: 2, text: "Praise be to God" },
  ]);
});

test("parseFawazEdition accepts a JSON string and rejects the wrong shape", () => {
  assert.equal(parseFawazEdition('{"quran":[{"chapter":2,"verse":3,"text":"x"}]}')[0].surah, 2);
  assert.throws(() => parseFawazEdition({ verses: [] }), /quran/);
});

/* -------------------------------------------------------------------------- */

test("parseQuranEncSura keeps the translation and drops arabic_text/footnotes", () => {
  const rows = parseQuranEncSura({
    result: [
      {
        sura: "1",
        aya: "1",
        arabic_text: "بِسۡمِ ٱللَّهِ",
        translation: "In the name of Allāh,[2] the Entirely Merciful.[3]",
        footnotes: "[2] Allāh is a proper name...",
      },
    ],
  });
  assert.equal(rows.length, 1);
  assert.deepEqual(rows[0], {
    surah: 1,
    ayah: 1,
    text: "In the name of Allāh, the Entirely Merciful.",
  });
  assert.equal(hasArabic(rows[0].text), false);
});

test("parseQuranEncSura rejects a response without a result array", () => {
  assert.throws(() => parseQuranEncSura({ error: "nope" }), /result/);
});

/* -------------------------------------------------------------------------- */

test("cleanTranslation strips numeric footnote markers only", () => {
  assert.equal(cleanTranslation("Say[1], he is One."), "Say, he is One.");
  assert.equal(cleanTranslation("word (1) after"), "word after");
  assert.equal(
    cleanTranslation("[of] the people [i.e., mankind]"),
    "[of] the people [i.e., mankind]",
    "bracketed words are Saheeh's interpolation convention and must survive",
  );
});

test("cleanTranslation strips HTML tags and decodes entities", () => {
  assert.equal(cleanTranslation("a &amp; b<br>c"), "a & b c");
  assert.equal(cleanTranslation("&#x201C;Say&#x201D;"), "“Say”");
  assert.equal(cleanTranslation("<i>Alif</i> <b>Lam</b>"), "Alif Lam");
});

test("cleanTranslation removes the Arabic honorific ligatures and their brackets", () => {
  assert.equal(
    cleanTranslation("upon Our Servant [i.e., Prophet Muḥammad (ﷺ)], then produce"),
    "upon Our Servant [i.e., Prophet Muḥammad], then produce",
  );
  assert.equal(cleanTranslation("The Prophet ﷺ said"), "The Prophet said");
  assert.equal(cleanTranslation("Allah [ﷻ], Lord"), "Allah, Lord");
  assert.equal(hasArabic(cleanTranslation("Prophet (ﷺ)")), false);
});

test("cleanTranslation collapses whitespace and never returns null", () => {
  assert.equal(cleanTranslation("  a\n\t b  "), "a b");
  assert.equal(cleanTranslation(null), "");
  assert.equal(cleanTranslation(undefined), "");
});

/* -------------------------------------------------------------------------- */

test("hasArabic / arabicChars detect Arabic script but not Latin transliteration", () => {
  assert.equal(hasArabic("Raḥmān, Allāh"), false);
  assert.equal(hasArabic("ٱللَّهُ"), true);
  assert.deepEqual(arabicChars("a ﷺ b ﷺ"), ["ﷺ"]);
});

/* -------------------------------------------------------------------------- */

const META_FIXTURE = `<?xml version="1.0" encoding="utf-8" ?>
<quran type="metadata" version="1.0">
  <suras>
    <sura index="1" ayas="3" start="0" name="الفاتحة" tname="Al-Faatiha" ename="The Opening" type="Meccan" order="5" rukus="1" />
    <sura index="2" ayas="4" start="3" name="البقرة" tname="Al-Baqara" ename="The Cow" type="Medinan" order="87" rukus="40" />
    <sura index="3" ayas="2" start="7" name="آل عمران" tname="Aal-i-Imraan" ename="The Family of Imraan" type="Medinan" order="89" rukus="20" />
  </suras>
  <juzs>
    <juz index="1" sura="1" aya="1" />
    <juz index="2" sura="2" aya="3" />
  </juzs>
  <pages>
    <page index="1" sura="1" aya="1" />
    <page index="2" sura="2" aya="1" />
    <page index="3" sura="3" aya="1" />
  </pages>
</quran>`;

test("parseQuranMetadata reads suras, juzs and pages", () => {
  const meta = parseQuranMetadata(META_FIXTURE, { expectSurahs: 3 });
  assert.equal(meta.suras.length, 3);
  assert.equal(meta.juzs.length, 2);
  assert.equal(meta.pages.length, 3);
  assert.equal(meta.suras[0].tname, "Al-Faatiha");
  assert.equal(meta.suras[1].start, 3);
});

test("parseQuranMetadata rejects a non-metadata document", () => {
  assert.throws(() => parseQuranMetadata("<html></html>"), /quran-data\.xml/);
});

test("buildSurahs derives startIndex, revelation, juz span and page span", () => {
  const surahs = buildSurahs(parseQuranMetadata(META_FIXTURE, { expectSurahs: 3 }));
  assert.deepEqual(surahs[0], {
    number: 1,
    name: "Al-Faatiha",
    meaning: "The Opening",
    ayahCount: 3,
    revelation: "makki",
    startIndex: 0,
    juz: [1],
    pages: [1, 1],
  });
  // Surah 2 spans global 3..6; juz 2 starts at 2:3 (global 5), so both juz overlap.
  assert.deepEqual(surahs[1].juz, [1, 2]);
  assert.equal(surahs[1].revelation, "madani");
  assert.deepEqual(surahs[1].pages, [2, 2]);
  assert.equal(surahs[2].startIndex, 7);
  assert.deepEqual(surahs[2].pages, [3, 3]);
  // startIndex stays monotone and the counts add up.
  assert.deepEqual(
    surahs.map((s) => s.startIndex),
    [0, 3, 7],
  );
});

test("buildSurahs rejects an unknown revelation type", () => {
  const meta = parseQuranMetadata(META_FIXTURE, { expectSurahs: 3 });
  meta.suras[0].type = "Martian";
  assert.throws(() => buildSurahs(meta), /unknown revelation type/);
});

/* -------------------------------------------------------------------------- */

test("flattenCanonical returns a flat array in canonical order", () => {
  const counts = [2, 3];
  const entries = [
    { surah: 1, ayah: 1, text: "a" },
    { surah: 1, ayah: 2, text: "b" },
    { surah: 2, ayah: 1, text: "c" },
    { surah: 2, ayah: 2, text: "d" },
    { surah: 2, ayah: 3, text: "e" },
  ];
  const flat = flattenCanonical(entries, counts, "fixture");
  assert.deepEqual(flat, ["a", "b", "c", "d", "e"]);
});

test("flattenCanonical rejects a short array and an out-of-order entry", () => {
  const counts = [2];
  assert.throws(
    () => flattenCanonical([{ surah: 1, ayah: 1, text: "a" }], counts, "fixture"),
    /expected 6236 entries|expected 2 entries/,
  );
  assert.throws(
    () =>
      flattenCanonical(
        [
          { surah: 1, ayah: 2, text: "b" },
          { surah: 1, ayah: 1, text: "a" },
        ],
        counts,
        "fixture",
      ),
    /expected 6236 entries|expected 1:1/,
  );
});

test("canonical ayah counts describe 114 surahs and 6,236 ayat", () => {
  assert.equal(CANONICAL_AYAH_COUNTS.length, 114);
  assert.equal(
    CANONICAL_AYAH_COUNTS.reduce((a, b) => a + b, 0),
    TOTAL_AYAHS,
  );
  assert.equal(CANONICAL_AYAH_COUNTS[1], 286, "surah 2 has 286 ayat");
  assert.equal(CANONICAL_AYAH_COUNTS[113], 6, "surah 114 has 6 ayat");
});

/* -------------------------------------------------------------------------- */

test("buildRegistry pins the exact ids, abbreviations and attribution strings", () => {
  const reg = buildRegistry({ saheehVersion: "1.1.2", ruwwadVersion: "1.0.19" });
  assert.deepEqual(
    reg.map((e) => e.id),
    ["itani", "saheeh", "ruwwad", "pickthall"],
  );
  for (const entry of reg) {
    for (const field of REGISTRY_FIELDS) assert.ok(Object.hasOwn(entry, field), `${entry.id}.${field}`);
    assert.equal(entry.language, "en");
    assert.equal(entry.offline, true);
    for (const [f, want] of Object.entries(REQUIRED_STRINGS[entry.id])) {
      assert.equal(entry[f], want);
    }
  }
  assert.equal(reg.filter((e) => e.isDefault).length, 1);
  assert.equal(reg[0].isDefault, true, "Itani is the default translation");
  assert.match(reg[1].copyright, /version 1\.1\.2/);
  assert.match(reg[2].copyright, /version 1\.0\.19/);
});
