// Arabic text helpers shared by validate.mjs, search.mjs and the authoring tools.
//
// Two comparisons matter when checking that a `keyTerms[].arabic` was really
// copied out of the Uthmani text:
//
//   exact  — NFC, every mark kept. This is what the content rule demands.
//   loose  — diacritics folded away, so "the word is in the passage but was
//            retyped" can be told apart from "the word is not in the passage".
//
// The traps the loose form exists to absorb (all of them have bitten an author):
//   U+0640 TATWEEL        Uthmani carries a dagger alef on a tatweel: بَـٰبِ,
//                         so a hand-typed بَٰبِ is one codepoint short.
//   U+0670 SUPERSCRIPT ALEF is a written alef, not a vowel sign: قَـٰسِيَةً is
//                         the same word as a hand-typed قَاسِيَةً.
//   U+06D6–U+06ED         Quranic annotation signs (small high seen, sajdah,
//                         the pause marks) sit inside tokens and are invisible.
//   U+0671 ALEF WASLA     ٱلْ is not ا + ل: the definite article in Uthmani is
//                         almost always the wasla form.
//   U+0649 / U+064A       final alef maqsura vs ya, indistinguishable by ear.
//   U+0622/23/25          alef madda / hamza above / hamza below.
//   U+0629 / U+0647       ta marbuta vs ha.
export const TATWEEL = "ـ";
export const SUPERSCRIPT_ALEF = "ٰ";

/** Combining marks that carry no letter: harakat, tanwin, sukun, Quranic signs. */
const MARKS = /[ً-ٟۖ-ۭ࣓-ࣿﹰ-ﹿ]/g;

export const nfc = (s) => String(s ?? "").normalize("NFC");

/**
 * Diacritics-insensitive form. Marks and tatweel disappear; the dagger alef
 * becomes a real alef because that is what it spells; alef, ya and ta marbuta
 * variants collapse. Whitespace is squeezed to single spaces.
 */
export function looseArabic(s) {
  return nfc(s)
    .replace(new RegExp(SUPERSCRIPT_ALEF, "g"), "ا")
    .replace(MARKS, "")
    .replace(new RegExp(TATWEEL, "g"), "")
    .replace(/[آأإٱٲٳ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/** The unit's own Uthmani text: ayat start..end joined by a single space, NFC. */
export function unitUthmani(quran, { surah, start, end }) {
  const parts = [];
  for (let a = start; a <= end; a++) parts.push(stripBasmala(quran.uthmani(surah, a), surah, a));
  return nfc(parts.join(" "));
}

/**
 * Loose form of `text` plus, for every character of it, the index of the
 * character in `text` it came from. Lets a loose match be mapped back to the
 * exact substring that produced it.
 */
export function looseIndex(text) {
  const src = nfc(text);
  let out = "";
  const map = [];
  let pendingSpace = false;
  for (let i = 0; i < src.length; i++) {
    const folded = looseArabic(src[i]);
    if (/\s/.test(src[i])) {
      if (out) pendingSpace = true;
      continue;
    }
    if (!folded) continue;
    if (pendingSpace) {
      out += " ";
      map.push(i);
      pendingSpace = false;
    }
    for (const ch of folded) {
      out += ch;
      map.push(i);
    }
  }
  return { loose: out, map, src };
}

/**
 * The exact substring of `haystack` whose loose form is `needle`'s loose form,
 * or null. Trailing marks and tatweel are pulled in, so the result is the
 * passage's own spelling of the term, ready to paste into `keyTerms[].arabic`.
 */
export function exactSpanFor(haystack, needle) {
  const { loose, map, src } = looseIndex(haystack);
  const want = looseArabic(needle);
  if (!want) return null;
  // Prefer a whole-token match: 2:270 contains both نَذَرْتُم and نَّذْرٍ, and the
  // first loose hit for نذر sits inside the longer verb.
  const starts = [];
  for (let at = loose.indexOf(want); at !== -1; at = loose.indexOf(want, at + 1)) starts.push(at);
  if (!starts.length) return null;
  const aligned = (at) =>
    (at === 0 || loose[at - 1] === " ") &&
    (at + want.length === loose.length || loose[at + want.length] === " ");
  const at = starts.find(aligned) ?? starts[0];
  const from = map[at];
  let to = map[at + want.length - 1];
  while (to + 1 < src.length && !looseArabic(src[to + 1]) && !/\s/.test(src[to + 1])) to++;
  return src.slice(from, to + 1);
}

/**
 * Tanzil's Uthmani text prefixes ayah 1 of every surah but 1 and 9 with the
 * Bismillah, kept verbatim under its licence. It is not part of the ayah, so a
 * key term must not be able to "occur in the passage" by matching it.
 * Mirrors `ArabicText.stripBasmala` in the app.
 */
export const BASMALA = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ";

export function stripBasmala(text, surah, ayah) {
  if (ayah !== 1 || surah === 1 || surah === 9) return text;
  const t = nfc(text);
  return t.startsWith(BASMALA) ? t.slice(BASMALA.length).trimStart() : t;
}
