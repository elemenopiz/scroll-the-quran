// Canonical Quran shape constants and small helpers shared by the ingest scripts.
// Node 24 built-ins only.

/** Total number of ayat in the canonical (Hafs / Kufan) counting used by Tanzil. */
export const TOTAL_AYAHS = 6236;

/** Number of surahs. */
export const TOTAL_SURAHS = 114;

/** Number of juz (parts). */
export const TOTAL_JUZ = 30;

/** Number of mushaf pages in the Madinah mushaf layout Tanzil ships. */
export const TOTAL_PAGES = 604;

/**
 * Unicode blocks that carry Arabic script.
 * Arabic, Arabic Supplement, Arabic Extended-B/A, Arabic Presentation Forms-A/B.
 */
export const ARABIC_RE =
  /[؀-ۿݐ-ݿࡰ-࢟ࢠ-ࣿﭐ-﷿ﹰ-﻿]/u;

/** True when `s` contains at least one Arabic-script character. */
export function hasArabic(s) {
  return typeof s === "string" && ARABIC_RE.test(s);
}

/** Every Arabic-script character in `s`, de-duplicated, in order of first appearance. */
export function arabicChars(s) {
  const out = [];
  const seen = new Set();
  for (const ch of String(s)) {
    if (ARABIC_RE.test(ch) && !seen.has(ch)) {
      seen.add(ch);
      out.push(ch);
    }
  }
  return out;
}

/** "2:255" verse key from surah + ayah numbers. */
export function verseKey(surah, ayah) {
  return `${surah}:${ayah}`;
}

/**
 * Canonical ordering comparator / key for an entry `{ surah, ayah }`.
 * Canonical order is surah 1 ayah 1 ... surah 114 ayah 6.
 */
export function orderKey(surah, ayah) {
  return surah * 10000 + ayah;
}

/**
 * Assert that `entries` (array of `{ surah, ayah, text }`) is exactly the canonical
 * 6,236-verse sequence for the given per-surah ayah counts.
 * Returns a flat array of 6,236 strings. Throws on any violation.
 */
export function flattenCanonical(entries, ayahCounts, label) {
  if (!Array.isArray(entries)) {
    throw new Error(`${label}: expected an array of entries, got ${typeof entries}`);
  }
  const expected = ayahCounts.reduce((a, b) => a + b, 0);
  if (entries.length !== expected) {
    throw new Error(`${label}: expected ${expected} entries, got ${entries.length}`);
  }
  const flat = new Array(expected);
  let i = 0;
  for (let surah = 1; surah <= ayahCounts.length; surah += 1) {
    const count = ayahCounts[surah - 1];
    for (let ayah = 1; ayah <= count; ayah += 1) {
      const entry = entries[i];
      if (entry.surah !== surah || entry.ayah !== ayah) {
        throw new Error(
          `${label}: entry ${i} is ${entry.surah}:${entry.ayah}, expected ${surah}:${ayah}`,
        );
      }
      flat[i] = entry.text;
      i += 1;
    }
  }
  return flat;
}

/**
 * The 114 canonical ayah counts, in surah order. Used as a cross-check against
 * whatever the metadata source reports; never as the primary source.
 */
export const CANONICAL_AYAH_COUNTS = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53,
  89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12,
  12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26,
  30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];
