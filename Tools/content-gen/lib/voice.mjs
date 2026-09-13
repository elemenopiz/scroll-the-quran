// The voice pass (docs/content/voice.md, prompts/simplify.md): the rules that
// separate a note that talks *to the reader about the verse* from one that
// talks about the note. Measured, not judged: structure-talk phrases, and
// stacks of fragments where the first pass split long sentences into stubs.
import { sentences, wordsOf } from "./readability.mjs";

/** The `meta.simplified` stamp a voice-pass rewrite carries. Bump to re-open the corpus. */
export const VOICE_VERSION = "v2";

/** Sections the structure-talk rule applies to. Did-you-know may talk structure. */
export const VOICE_FIELDS = ["meaning", "historicalContext", "lifeInProphetsTime", "theologicalSignificance", "applyIt"];

/** Phrases that describe the note's or the passage's anatomy instead of what it says. */
export const STRUCTURE_TALK = [
  /\b(the|this) (ayah|verse|passage|surah|section|sentence|clause|unit)( itself)? (is|was) (built|structured|composed|arranged|framed|made up|constructed)\b/i,
  /\b(three|four|five|two) (statements|clauses|sentences|assertions|denials|moves|steps)\b,? (each|the)\b/i,
  /\b(the|its) (final|last|first|second|third|opening|closing|middle) (clause|sentence|half|statement|phrase|line)\b/i,
  /\b(in|of) (structure|syntax)\b/i,
  /\b(in|of|by) (its )?(structure|syntax|form)\b/i,
  /\b(the|this) (ayah|verse|passage) (reads|works|functions|operates) (as|like) a\b/i,
  /\bnominali[sz]ation|grammatical(ly)? (form|marker)\b/i,
  /\bthe (rhetorical|literary) (structure|device|move)\b/i,
];

/** Words of six or fewer read as a fragment when they come three in a row. */
export const FRAGMENT_WORDS = 6;
export const FRAGMENT_RUN = 3;
export const FRAGMENT_SHARE = 0.4;
export const MIN_MEAN_WORDS = 9;

/**
 * Findings for one section, as plain strings. Empty when the prose passes.
 * @param {string} field
 * @param {string} text
 */
export function voiceFindings(field, text) {
  const out = [];
  const t = String(text ?? "");
  if (!t.trim()) return out;
  if (VOICE_FIELDS.includes(field)) {
    for (const re of STRUCTURE_TALK) {
      const m = re.exec(t);
      if (m) { out.push(`${field}: talks about the passage's structure ("${m[0]}") — say what it says instead`); break; }
    }
  }
  const lens = sentences(t).map((s) => wordsOf(s).length);
  if (lens.length >= 3) {
    let run = 0;
    for (const n of lens) {
      run = n <= FRAGMENT_WORDS ? run + 1 : 0;
      if (run >= FRAGMENT_RUN) { out.push(`${field}: ${FRAGMENT_RUN} fragments in a row (≤${FRAGMENT_WORDS} words each) — join them`); break; }
    }
    const short = lens.filter((n) => n <= FRAGMENT_WORDS).length / lens.length;
    if (short > FRAGMENT_SHARE) out.push(`${field}: ${Math.round(short * 100)}% of sentences are fragments — vary the rhythm`);
    const mean = lens.reduce((a, b) => a + b, 0) / lens.length;
    if (mean < MIN_MEAN_WORDS) out.push(`${field}: ${mean.toFixed(1)} words per sentence is choppy (floor ${MIN_MEAN_WORDS})`);
  }
  return out;
}
