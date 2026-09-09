// Pure parsers for every upstream source used by the ingest scripts.
// No I/O, no network: everything here takes a string (or parsed JSON) and returns data.
// Node 24 built-ins only.

import { TOTAL_SURAHS } from "./quran.mjs";

/* -------------------------------------------------------------------------- */
/* Tanzil plain-text Quran ("sura|aya|text" lines)                             */
/* -------------------------------------------------------------------------- */

/**
 * Parse Tanzil's `outType=txt-2` download.
 * Lines look like `2|255|ٱللَّهُ لَآ إِلَـٰهَ ...`; a copyright block of `#` comment
 * lines and blank lines surround the data.
 *
 * @param {string} text raw UTF-8 download body
 * @returns {{surah:number, ayah:number, text:string}[]}
 */
export function parseTanzilText(text) {
  if (typeof text !== "string" || text.length === 0) {
    throw new Error("parseTanzilText: empty input");
  }
  const out = [];
  const lines = text.split(/\r?\n/);
  for (let n = 0; n < lines.length; n += 1) {
    const line = lines[n];
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) continue;
    const first = trimmed.indexOf("|");
    const second = trimmed.indexOf("|", first + 1);
    if (first < 1 || second < 0) {
      throw new Error(`parseTanzilText: line ${n + 1} is not "sura|aya|text": ${trimmed.slice(0, 40)}`);
    }
    const surah = Number(trimmed.slice(0, first));
    const ayah = Number(trimmed.slice(first + 1, second));
    // The text itself may legitimately contain "|" in theory; keep everything after
    // the second separator verbatim (only outer whitespace is trimmed).
    const verse = trimmed.slice(second + 1).trim();
    if (!Number.isInteger(surah) || !Number.isInteger(ayah) || surah < 1 || ayah < 1) {
      throw new Error(`parseTanzilText: line ${n + 1} has a bad sura/aya number`);
    }
    if (verse === "") {
      throw new Error(`parseTanzilText: ${surah}:${ayah} has empty text`);
    }
    out.push({ surah, ayah, text: verse });
  }
  if (out.length === 0) {
    throw new Error("parseTanzilText: no verse lines found (did the download return HTML?)");
  }
  return out;
}

/**
 * Extract the `#`-prefixed copyright block Tanzil embeds in every download.
 * @param {string} text
 * @returns {string} the comment block with the leading "# " markers removed
 */
export function extractTanzilCopyright(text) {
  return String(text)
    .split(/\r?\n/)
    .filter((l) => l.trimStart().startsWith("#"))
    .map((l) => l.trimStart().replace(/^#\s?/, "").trimEnd())
    .join("\n")
    .trim();
}

/* -------------------------------------------------------------------------- */
/* fawazahmed0 quran-api editions                                              */
/* -------------------------------------------------------------------------- */

/**
 * Parse a fawazahmed0/quran-api v1 edition file: `{ quran: [{chapter, verse, text}] }`.
 * @param {object|string} json parsed object or raw JSON string
 * @returns {{surah:number, ayah:number, text:string}[]}
 */
export function parseFawazEdition(json) {
  const doc = typeof json === "string" ? JSON.parse(json) : json;
  if (!doc || !Array.isArray(doc.quran)) {
    throw new Error('parseFawazEdition: expected a top-level "quran" array');
  }
  return doc.quran.map((row, i) => {
    const surah = Number(row.chapter);
    const ayah = Number(row.verse);
    if (!Number.isInteger(surah) || !Number.isInteger(ayah)) {
      throw new Error(`parseFawazEdition: row ${i} has a bad chapter/verse`);
    }
    return { surah, ayah, text: String(row.text ?? "").trim() };
  });
}

/* -------------------------------------------------------------------------- */
/* QuranEnc sura endpoint                                                      */
/* -------------------------------------------------------------------------- */

/**
 * Parse one QuranEnc `/api/v1/translation/sura/{key}/{n}` response.
 * Returns the cleaned translation only; `arabic_text` and `footnotes` are dropped
 * on purpose (the Arabic layer comes from Tanzil, footnotes are not shipped).
 *
 * @param {object|string} json
 * @returns {{surah:number, ayah:number, text:string}[]}
 */
export function parseQuranEncSura(json) {
  const doc = typeof json === "string" ? JSON.parse(json) : json;
  const rows = doc && doc.result;
  if (!Array.isArray(rows)) {
    throw new Error('parseQuranEncSura: expected a "result" array');
  }
  return rows.map((row, i) => {
    const surah = Number(row.sura);
    const ayah = Number(row.aya);
    if (!Number.isInteger(surah) || !Number.isInteger(ayah)) {
      throw new Error(`parseQuranEncSura: row ${i} has a bad sura/aya`);
    }
    return { surah, ayah, text: cleanTranslation(row.translation) };
  });
}

const HTML_ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  ldquo: "“",
  rdquo: "”",
  lsquo: "‘",
  rsquo: "’",
  hellip: "…",
  ndash: "–",
  mdash: "—",
};

/**
 * Normalise a translation string coming from an upstream API.
 *
 * - decodes HTML entities (named + numeric)
 * - turns `<br>` and friends into spaces, then strips every remaining tag
 * - removes inline footnote markers: `[1]`, `[12]`, `(1)` at a word boundary,
 *   and superscript digit runs. Bracketed *words* (`[of]`, `[Allah]`) are
 *   Saheeh International's interpolation convention and are deliberately kept.
 * - removes the Arabic honorific ligatures U+FDFA (ﷺ) and U+FDFB (ﷻ), together
 *   with the parentheses that wrap them. The app keeps English translation text
 *   free of Arabic script - the Arabic Uthmani line is a separate design layer -
 *   so these glyphs are dropped rather than transliterated or paraphrased.
 * - collapses whitespace and fixes the space left before punctuation
 *
 * @param {unknown} raw
 * @returns {string}
 */
export function cleanTranslation(raw) {
  let s = String(raw ?? "");
  // Tags first turn into spaces so "a<br>b" does not become "ab".
  s = s.replace(/<[^>]*>/g, " ");
  s = decodeEntities(s);
  // Entities may themselves have encoded a tag; strip once more.
  s = s.replace(/<[^>]*>/g, " ");
  // Arabic honorific ligatures, with any parentheses/brackets that wrap them.
  s = s.replace(/[\uFDFA\uFDFB]/g, HONORIFIC_PLACEHOLDER);
  s = s.replace(new RegExp(`[(\\[]\\s*${HONORIFIC_PLACEHOLDER}\\s*[)\\]]`, "g"), "");
  s = s.replace(new RegExp(HONORIFIC_PLACEHOLDER, "g"), "");
  // Footnote markers.
  s = s.replace(/\[\s*\d+\s*\]/g, "");
  s = s.replace(/\(\s*\d+\s*\)(?=[\s.,;:!?"'”’)]|$)/g, "");
  s = s.replace(/[⁰¹²³⁴-⁹]+/g, "");
  // Whitespace.
  s = s.replace(/[ ​‎‏]/g, " ");
  s = s.replace(/\s+/g, " ").trim();
  // A removed marker can leave " ." or " ,".
  s = s.replace(/\s+([.,;:!?])/g, "$1");
  s = s.replace(/\(\s+/g, "(").replace(/\s+\)/g, ")");
  s = s.replace(/\[\s+/g, "[").replace(/\s+\]/g, "]");
  s = s.replace(/\(\s*\)|\[\s*\]/g, "");
  s = s.replace(/\s+/g, " ").trim();
  return s;
}

/** Sentinel used while stripping honorifics; never survives cleanTranslation. */
const HONORIFIC_PLACEHOLDER = "\u0000H\u0000";

function decodeEntities(s) {
  return s
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => safeCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => safeCodePoint(parseInt(dec, 10)))
    .replace(/&([a-zA-Z]+);/g, (m, name) => {
      const key = name.toLowerCase();
      return Object.hasOwn(HTML_ENTITIES, key) ? HTML_ENTITIES[key] : m;
    });
}

function safeCodePoint(cp) {
  if (!Number.isInteger(cp) || cp < 0 || cp > 0x10ffff) return "";
  try {
    return String.fromCodePoint(cp);
  } catch {
    return "";
  }
}

/* -------------------------------------------------------------------------- */
/* Tanzil quran-data.xml metadata                                              */
/* -------------------------------------------------------------------------- */

/**
 * Parse Tanzil's `quran-data.xml` without an XML dependency: the file is a flat,
 * attribute-only document, so a tag-level regex sweep is exact here.
 *
 * @param {string} xml
 * @param {{expectSurahs?:number}} [opts] override the expected <sura> count (tests use tiny fixtures)
 * @returns {{suras:object[], juzs:object[], pages:object[]}}
 */
export function parseQuranMetadata(xml, opts = {}) {
  const expectSurahs = opts.expectSurahs ?? TOTAL_SURAHS;
  if (typeof xml !== "string" || !xml.includes("<quran")) {
    throw new Error("parseQuranMetadata: input does not look like quran-data.xml");
  }
  const suras = collect(xml, "sura").map((a) => ({
    index: int(a.index, "sura.index"),
    ayas: int(a.ayas, "sura.ayas"),
    start: int(a.start, "sura.start"),
    name: a.name,
    tname: a.tname,
    ename: a.ename,
    type: a.type,
    order: int(a.order, "sura.order"),
    rukus: int(a.rukus, "sura.rukus"),
  }));
  const juzs = collect(xml, "juz").map((a) => ({
    index: int(a.index, "juz.index"),
    sura: int(a.sura, "juz.sura"),
    aya: int(a.aya, "juz.aya"),
  }));
  const pages = collect(xml, "page").map((a) => ({
    index: int(a.index, "page.index"),
    sura: int(a.sura, "page.sura"),
    aya: int(a.aya, "page.aya"),
  }));
  if (suras.length !== expectSurahs) {
    throw new Error(`parseQuranMetadata: expected ${expectSurahs} <sura> elements, got ${suras.length}`);
  }
  return { suras, juzs, pages };
}

function collect(xml, tag) {
  const re = new RegExp(`<${tag}\\b([^>]*)/?>`, "g");
  const out = [];
  for (const m of xml.matchAll(re)) out.push(attrs(m[1]));
  return out;
}

function attrs(chunk) {
  const out = {};
  for (const m of chunk.matchAll(/([a-zA-Z_:][-\w:.]*)\s*=\s*"([^"]*)"/g)) {
    out[m[1]] = decodeEntities(m[2]);
  }
  return out;
}

function int(v, what) {
  const n = Number(v);
  if (!Number.isInteger(n)) throw new Error(`parseQuranMetadata: ${what} is not an integer: ${v}`);
  return n;
}

/**
 * Build the 114-entry `surahs.json` payload from parsed Tanzil metadata.
 *
 * - `startIndex` is the 0-based global index of the surah's first ayah
 *   (so global index = startIndex + ayah - 1, i.e. 2:255 -> 261).
 * - `juz` lists every juz whose span overlaps the surah, ascending.
 * - `pages` is `[firstPage, lastPage]` in the Madinah mushaf.
 *
 * @param {{suras:object[], juzs:object[], pages:object[]}} meta
 * @returns {object[]}
 */
export function buildSurahs(meta) {
  const { suras, juzs, pages } = meta;
  const counts = suras.map((s) => s.ayas);
  const globalOf = (sura, aya) => suras[sura - 1].start + aya - 1;

  const total = counts.reduce((a, b) => a + b, 0);
  const juzStarts = juzs
    .map((j) => ({ index: j.index, start: globalOf(j.sura, j.aya) }))
    .sort((a, b) => a.start - b.start);
  const pageStarts = pages
    .map((p) => ({ index: p.index, start: globalOf(p.sura, p.aya) }))
    .sort((a, b) => a.start - b.start);

  const spanOf = (starts, from, to) => {
    // starts is ascending; a unit covers [start, nextStart).
    const hit = [];
    for (let i = 0; i < starts.length; i += 1) {
      const s = starts[i].start;
      const e = i + 1 < starts.length ? starts[i + 1].start : total;
      if (s < to && e > from) hit.push(starts[i].index);
    }
    return hit;
  };

  return suras.map((s) => {
    const from = s.start;
    const to = s.start + s.ayas;
    const juz = spanOf(juzStarts, from, to);
    const pageSpan = spanOf(pageStarts, from, to);
    return {
      number: s.index,
      name: s.tname,
      meaning: s.ename,
      ayahCount: s.ayas,
      revelation: revelationOf(s.type),
      startIndex: s.start,
      juz,
      pages: [pageSpan[0], pageSpan[pageSpan.length - 1]],
    };
  });
}

function revelationOf(type) {
  const t = String(type).toLowerCase();
  if (t === "meccan" || t === "makki" || t === "makkah") return "makki";
  if (t === "medinan" || t === "madani" || t === "madinah") return "madani";
  throw new Error(`buildSurahs: unknown revelation type "${type}"`);
}
