// Readability: Flesch–Kincaid grade level and mean sentence length.
//
// One module, one syllable heuristic. The measuring pass (`author.mjs
// rewrite-todo`), the rewrite prompt and the validator all call the same
// functions, so a section that measures 8.4 in the todo list measures 8.4 in
// `validate.mjs` — an author must never have to guess which counter is in play.
//
// The numbers are heuristics, not truths: English syllable counting cannot be
// done exactly without a pronouncing dictionary. What matters is that the
// heuristic is stable, cheap and identical on both sides of the pipeline.
//
// Nothing here reads the disk or the network.

/**
 * Sentence-final abbreviations that must not end a sentence. Deliberately tiny:
 * the content rules already ban "e.g."-style prose, and every extra entry is a
 * chance to swallow a real sentence break.
 */
const ABBREVIATIONS = new Set([
  "mr", "mrs", "ms", "dr", "st", "vs", "etc", "e.g", "i.e", "ca", "cf", "al",
]);

/** Trailing quotes/brackets that may follow the full stop of a sentence. */
const CLOSERS = String.raw`["'”’»)\]]`;

/** Split a prose field into sentences. Never returns an empty list for non-empty text. */
export function sentences(text) {
  const t = String(text ?? "").replace(/\s+/g, " ").trim();
  if (!t) return [];
  // The closing quote of `He said "stop."` belongs to the sentence it ends, so it
  // sits inside the lookbehind rather than in the separator.
  const pieces = t.split(new RegExp(`(?<=[.!?…]${CLOSERS}*)\\s+`, "u"));

  // Re-join a break that fell after an abbreviation or an initial ("W. Montgomery
  // Watt", "al-Sa'di"): those full stops are not sentence ends.
  const joined = [];
  for (const piece of pieces) {
    const prev = joined[joined.length - 1];
    if (prev !== undefined && endsWithAbbreviation(prev)) joined[joined.length - 1] = `${prev} ${piece}`;
    else joined.push(piece);
  }
  const kept = joined.map((s) => s.trim()).filter((s) => /\p{L}|\p{N}/u.test(s));
  return kept.length ? kept : [t];
}

function endsWithAbbreviation(sentence) {
  const m = /([\p{L}.]+)\.$/u.exec(sentence.trim());
  if (!m) return false;
  const word = m[1].toLowerCase();
  // A single letter is an initial.
  return word.length === 1 || ABBREVIATIONS.has(word) || ABBREVIATIONS.has(word.replace(/\.$/, ""));
}

/**
 * The words of a prose field, for readability only.
 *
 * `words()` in lib/data.mjs counts whitespace tokens and is what the schema's
 * word bounds are measured with; this one additionally drops tokens with no
 * letter or digit (a lone dash, a stray bullet) so they cannot pull the
 * syllables-per-word ratio down.
 */
export function wordsOf(text) {
  return String(text ?? "")
    .split(/\s+/)
    .map((w) => w.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}']+$/gu, ""))
    .filter((w) => /\p{L}|\p{N}/u.test(w));
}

/**
 * A silent final "e"/"es"/"ed" removed, so the vowel-group count below does not
 * credit it with a syllable.
 *
 * "-ed" is its own syllable only after t or d ("wanted", "needed"), "-es" only
 * after a sibilant ("verses", "places"), and a final "e" is silent unless it
 * carries the "-le" of "simple" or follows another vowel ("queue").
 */
function dropSilentEnding(w) {
  if (w.endsWith("ed")) {
    const stem = w.slice(0, -2);
    return /[tdaeiouy]$/.test(stem) ? w : stem;
  }
  if (w.endsWith("es")) {
    const stem = w.slice(0, -2);
    return /([cgsxz]|[cs]h)$/.test(stem) || /[aeiouy]$/.test(stem) ? w : stem;
  }
  if (w.endsWith("e")) {
    const stem = w.slice(0, -1);
    return /[laeiouy]$/.test(stem) ? w : stem;
  }
  return w;
}

/**
 * Syllables in one word, by the classic vowel-group heuristic: count runs of
 * vowels once a silent ending and a leading consonantal "y" are gone. Words of
 * three letters or fewer are one syllable.
 *
 * Known misses ("created" scores 2, "business" scores 3) are within the noise of
 * a grade level computed over a 40-100 word section.
 */
export function syllables(word) {
  const w = String(word ?? "").toLowerCase().replace(/[^a-z]/g, "");
  if (!w) return 0;
  if (w.length <= 3) return 1;
  const groups = dropSilentEnding(w).replace(/^y/, "").match(/[aeiouy]+/g);
  return Math.max(1, groups ? groups.length : 1);
}

/** Words of `minSyllables` syllables or more, lowercased, in order of appearance. */
export function longWords(text, { minSyllables = 4 } = {}) {
  return wordsOf(text)
    .map((w) => w.toLowerCase().replace(/[^a-z'-]/g, ""))
    .filter((w) => w && syllables(w) >= minSyllables);
}

const round = (n) => Math.round(n * 10) / 10;

/**
 * Every readability measure for one prose field.
 *
 * Empty text scores 0 across the board rather than NaN.
 */
export function readability(text) {
  const ss = sentences(text);
  const ws = wordsOf(text);
  const syl = ws.reduce((n, w) => n + syllables(w), 0);
  if (!ws.length || !ss.length) {
    return { words: 0, sentences: 0, syllables: 0, wordsPerSentence: 0, syllablesPerWord: 0, grade: 0 };
  }
  const wordsPerSentence = ws.length / ss.length;
  const syllablesPerWord = syl / ws.length;
  const grade = 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59;
  return {
    words: ws.length,
    sentences: ss.length,
    syllables: syl,
    wordsPerSentence: round(wordsPerSentence),
    syllablesPerWord: round(syllablesPerWord),
    // A grade level is never negative in practice; clamp so "Go now." does not
    // report -2.8 and make a table of scores unreadable.
    grade: round(Math.max(0, grade)),
  };
}

/** Flesch-Kincaid grade level of one prose field. */
export const fleschKincaidGrade = (text) => readability(text).grade;

/** Mean words per sentence of one prose field. */
export const meanSentenceLength = (text) => readability(text).wordsPerSentence;
