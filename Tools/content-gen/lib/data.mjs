// Shared loader for Quran text + surah metadata.
//
// Prefers the committed output of the 2a ingest task (`out/quran/*.json`).
// Falls back to raw downloads cached in `work/quran/` (gitignored) so this
// pipeline can run before 2a lands. Both paths produce identical shapes.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
export const OUT = path.join(ROOT, "out");
export const WORK = path.join(ROOT, "work");

const ARABIC_RE = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/;
export const hasArabic = (s) => ARABIC_RE.test(s);

const readJSON = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const exists = (p) => fs.existsSync(p);

function parseTanzilMetadata(xml) {
  const suras = [...xml.matchAll(/<sura\s+([^/>]+)\/>/g)].map((m) => {
    const attrs = Object.fromEntries(
      [...m[1].matchAll(/(\w+)="([^"]*)"/g)].map((a) => [a[1], a[2]]),
    );
    return {
      number: Number(attrs.index),
      name: attrs.tname.replace(/-/g, "-"),
      arabicName: attrs.name,
      meaning: attrs.ename,
      ayahCount: Number(attrs.ayas),
      revelation: attrs.type === "Meccan" ? "makki" : "madani",
      startIndex: Number(attrs.start),
      revelationOrder: Number(attrs.order),
      juz: [],
    };
  });
  const juzStarts = [...xml.matchAll(/<juz\s+([^/>]+)\/>/g)].map((m) => {
    const attrs = Object.fromEntries(
      [...m[1].matchAll(/(\w+)="([^"]*)"/g)].map((a) => [a[1], a[2]]),
    );
    return { juz: Number(attrs.index), surah: Number(attrs.sura), ayah: Number(attrs.aya) };
  });
  // Assign each ayah's juz by walking the juz start markers in order.
  const byNumber = new Map(suras.map((s) => [s.number, s]));
  const globalOf = (surah, ayah) => byNumber.get(surah).startIndex + ayah - 1;
  const marks = juzStarts.map((j) => ({ juz: j.juz, g: globalOf(j.surah, j.ayah) }));
  for (const s of suras) {
    const set = new Set();
    for (let a = 1; a <= s.ayahCount; a++) {
      const g = s.startIndex + a - 1;
      let j = 1;
      for (const m of marks) if (g >= m.g) j = m.juz;
      set.add(j);
    }
    s.juz = [...set].sort((x, y) => x - y);
  }
  return { suras, juzStarts };
}

let cache = null;

export function loadQuran() {
  if (cache) return cache;

  let surahs;
  const outSurahs = path.join(OUT, "quran", "surahs.json");
  if (exists(outSurahs)) {
    surahs = readJSON(outSurahs);
  } else {
    const xmlPath = path.join(WORK, "quran", "quran-data.xml");
    if (!exists(xmlPath)) {
      throw new Error(
        `No surah metadata. Expected ${outSurahs} (from the 2a ingest task) or ${xmlPath}.\n` +
          "Run: node fetch-inputs.mjs",
      );
    }
    surahs = parseTanzilMetadata(fs.readFileSync(xmlPath, "utf8")).suras;
  }

  const flat = (name, rawName) => {
    const outPath = path.join(OUT, "quran", `${name}.json`);
    if (exists(outPath)) return readJSON(outPath);
    const rawPath = path.join(WORK, "quran", rawName);
    if (!exists(rawPath)) {
      throw new Error(`Missing ${outPath} and ${rawPath}. Run: node fetch-inputs.mjs`);
    }
    const raw = readJSON(rawPath);
    const verses = raw.quran ?? raw;
    return verses.map((v) => (typeof v === "string" ? v : v.text));
  };

  const itani = flat("itani", "itani.raw.json");
  const arabic = flat("arabic-uthmani", "arabic.raw.json");

  if (itani.length !== 6236) throw new Error(`itani has ${itani.length} verses, expected 6236`);
  if (arabic.length !== 6236) throw new Error(`arabic has ${arabic.length} verses, expected 6236`);
  if (surahs.length !== 114) throw new Error(`surahs has ${surahs.length} entries, expected 114`);

  const byNumber = new Map(surahs.map((s) => [s.number, s]));
  const globalIndex = (surah, ayah) => byNumber.get(surah).startIndex + ayah - 1;

  cache = {
    surahs,
    byNumber,
    itani,
    arabic,
    globalIndex,
    english: (surah, ayah) => itani[globalIndex(surah, ayah)],
    uthmani: (surah, ayah) => arabic[globalIndex(surah, ayah)],
    juzOf(surah, ayah) {
      const s = byNumber.get(surah);
      // Approximate: a surah's juz list is ordered; pick by proportion of ayah
      // position across the juz boundaries recorded for the surah.
      return s.juz.length === 1 ? s.juz[0] : s.juz[Math.min(s.juz.length - 1, Math.floor(((ayah - 1) / s.ayahCount) * s.juz.length))];
    },
  };
  return cache;
}

// --- key helpers -------------------------------------------------------------

export const unitKey = (surah, start, end) =>
  start === end ? `${surah}:${start}` : `${surah}:${start}-${end}`;

export function parseKey(key) {
  const m = /^(\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?$/.exec(String(key).trim());
  if (!m) return null;
  const surah = Number(m[1]);
  const start = Number(m[2]);
  const end = m[3] === undefined ? start : Number(m[3]);
  return { surah, start, end };
}

/** True when `ref` ("2:255" or "2:255-257") names verses that actually exist. */
export function refInBounds(ref, byNumber) {
  const p = parseKey(ref);
  if (!p) return false;
  const s = byNumber.get(p.surah);
  if (!s) return false;
  return p.start >= 1 && p.end >= p.start && p.end <= s.ayahCount;
}

export const words = (s) => String(s).trim().split(/\s+/).filter(Boolean).length;
