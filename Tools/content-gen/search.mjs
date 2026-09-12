#!/usr/bin/env node
// search.mjs — find an Arabic term in the Uthmani text.
//
//   node search.mjs ٱلْمُتَّقِينَ                 # loose: diacritics ignored
//   node search.mjs ٱلْمُتَّقِينَ --exact          # NFC, every mark kept
//   node search.mjs ٱلصَّبْر --in 2:153-157       # only that unit, both ways
//   node search.mjs صبر --surah 2 --limit 20
//
// Loose mode is for finding a word; `--exact` answers the question validate.mjs
// actually asks — "is this string, character for character, in the passage?"
// The two disagree constantly, and every disagreement is one of these traps:
//
//   U+0640 TATWEEL            Uthmani hangs the dagger alef on a tatweel
//                             carrier: ٱلْأَلْبَـٰبِ, not ٱلْأَلْبَٰبِ. Retyping the word
//                             from a rendered page silently drops it.
//   U+0670 SUPERSCRIPT ALEF   a written alef, not a vowel: قَـٰسِيَةً is the same
//                             word you would type as قَاسِيَةً, and neither is a
//                             substring of the other.
//   U+06D6–U+06ED             the small high seen, the sajdah sign, the pause
//                             marks. Invisible in most editors, inside tokens.
//   U+0671 ALEF WASLA         the Uthmani definite article is ٱل, not ال.
//   U+0649 / U+064A           final alef maqsura vs ya.
//   U+0622 / U+0623 / U+0625  alef madda, hamza above, hamza below.
//   U+0629 / U+0647           ta marbuta vs ha.
//
// The other trap is not a normaliser at all: the text usually carries the word
// with a prefix. ٱلْمُتَّقِينَ is not in 25:74 — لِلْمُتَّقِينَ is. Neither mode will
// match across that, so when a search comes up empty it falls back to listing
// the tokens that *contain* the term, which is almost always what you wanted.
//
// Loose mode folds all of them (the dagger alef becomes a real alef, because
// that is what it spells). When loose finds a hit and `--exact` does not, the
// text's own spelling is printed as `exact:` — paste that into the body.
import { loadQuran, parseKey, unitKey } from "./lib/data.mjs";
import { loadPassages } from "./lib/units.mjs";
import { nfc, looseArabic, unitUthmani, exactSpanFor, stripBasmala } from "./lib/arabic.mjs";

const USAGE = `usage: node search.mjs <arabic term> [options]

  --exact        NFC, diacritics kept: exactly what validate.mjs requires of
                 keyTerms[].arabic. Without it the search is diacritics-
                 insensitive (tatweel, dagger alef, annotation signs, alef and
                 ya variants all folded).
  --in KEY       restrict to one unit or ayah range, e.g. --in 2:153-157
  --surah N      restrict to one surah
  --limit N      stop after N hits (default 40)
  --json         machine-readable hits
`;

function main(argv = process.argv.slice(2)) {
  const flag = (f) => argv.includes(f);
  const value = (f, d = null) => {
    const i = argv.indexOf(f);
    return i === -1 ? d : argv[i + 1];
  };
  const VALUE_FLAGS = new Set(["--in", "--surah", "--limit"]);
  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) {
      if (VALUE_FLAGS.has(argv[i])) i++;
      continue;
    }
    positional.push(argv[i]);
  }
  const term = nfc(positional.join(" "));
  if (!term) {
    console.log(USAGE);
    process.exit(2);
  }

  const exact = flag("--exact");
  const quran = loadQuran();
  const passages = loadPassages();
  const limit = Number(value("--limit", 40));

  let range = null;
  if (value("--in")) {
    range = parseKey(value("--in"));
    if (!range) {
      console.error(`--in: not a key or range: ${value("--in")}`);
      process.exit(2);
    }
  }
  const onlySurah = value("--surah") ? Number(value("--surah")) : range?.surah ?? null;

  const needle = exact ? term : looseArabic(term);
  const hits = [];
  outer: for (const s of quran.surahs) {
    if (onlySurah && s.number !== onlySurah) continue;
    for (let a = 1; a <= s.ayahCount; a++) {
      if (range && (a < range.start || a > range.end)) continue;
      const text = stripBasmala(quran.uthmani(s.number, a), s.number, a);
      const hay = exact ? nfc(text) : looseArabic(text);
      if (!hay.includes(needle)) continue;
      hits.push({
        ref: `${s.number}:${a}`,
        unit: passages[`${s.number}:${a}`] ?? null,
        exact: exact ? term : exactSpanFor(text, term),
        text,
      });
      if (hits.length >= limit) break outer;
    }
  }

  // The text usually carries the word with a prefix (لِ، بِ، وَ، لَ، فَ). A bare
  // search misses every one of those, so offer the tokens that contain it.
  const near = [];
  if (!hits.length) {
    const want = looseArabic(term);
    // A prefixed form does not contain the bare one: لِلْمُتَّقِينَ folds to "للمتقين",
    // which does not hold "المتقين" — the article's alef is elided in writing,
    // and بِـَٔايَـٰتِ loses the hamza carrier of ءَايَـٰتٍ the same way. Both are found
    // by matching the tail instead, allowing up to two letters of difference at
    // the front.
    const tail = want.length >= 4 ? want.slice(-Math.max(4, want.length - 2)) : null;
    outerNear: for (const s of quran.surahs) {
      if (onlySurah && s.number !== onlySurah) continue;
      for (let a = 1; a <= s.ayahCount; a++) {
        if (range && (a < range.start || a > range.end)) continue;
        const text = stripBasmala(quran.uthmani(s.number, a), s.number, a);
        for (const tok of nfc(text).split(/\s+/)) {
          const lt = looseArabic(tok);
          if (lt === want) continue;
          if (!lt.includes(want) && !(tail && lt.endsWith(tail))) continue;
          near.push({ ref: `${s.number}:${a}`, unit: passages[`${s.number}:${a}`] ?? null, token: tok });
          if (near.length >= limit) break outerNear;
        }
      }
    }
  }

  if (flag("--json")) {
    console.log(JSON.stringify({ term, mode: exact ? "exact" : "loose", hits, near }, null, 2));
    return;
  }

  console.log(`${exact ? "exact" : "loose"} search for ${term}${onlySurah ? ` in surah ${onlySurah}` : ""}`);
  for (const h of hits) {
    console.log(`\n${h.ref}  unit ${h.unit ?? "?"}`);
    if (!exact && h.exact && h.exact !== term) console.log(`  exact: ${h.exact}   <- the text's own spelling`);
    console.log(`  ${h.text}`);
  }
  console.log(`\n${hits.length} hit(s)${hits.length >= limit ? " (limit reached)" : ""}`);
  if (near.length) {
    console.log(`\nno exact occurrence, but ${near.length} token(s) carry it with a prefix:`);
    for (const n of near.slice(0, 12)) console.log(`  ${n.ref.padEnd(9)} unit ${String(n.unit ?? "?").padEnd(12)} ${n.token}`);
    if (near.length > 12) console.log(`  … ${near.length - 12} more`);
    console.log("  keyTerms[].arabic must be one of those, copied whole.");
  }

  // The question an author is really asking, answered without a second command.
  if (range) {
    const unitText = unitUthmani(quran, range);
    const verbatim = unitText.includes(term);
    const key = unitKey(range.surah, range.start, range.end);
    if (verbatim) {
      console.log(`\nverbatim in ${key}: yes — validate.mjs will accept this as keyTerms[].arabic`);
    } else if (looseArabic(unitText).includes(looseArabic(term))) {
      console.log(
        `\nverbatim in ${key}: NO — the word is there but spelled ${exactSpanFor(unitText, term)}; use that`,
      );
    } else {
      console.log(`\nverbatim in ${key}: NO — the word does not occur in those ayat at all`);
    }
  }
}

if (import.meta.url === `file://${process.argv[1]}`) main();
export { main };
