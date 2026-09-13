import test from "node:test";
import assert from "node:assert/strict";
import {
  syllables, sentences, wordsOf, longWords, readability, fleschKincaidGrade, meanSentenceLength,
} from "../lib/readability.mjs";

test("syllables counts the words the corpus actually trips over", () => {
  const expected = {
    the: 1, God: 1, one: 1, a: 1,
    commentators: 4, intercession: 4, accountability: 6, hypothetical: 5,
    lexicographers: 5, substitution: 4, revelation: 4,
    // Silent endings: "-ed" is a syllable only after t or d, "-es" only after a
    // sibilant, and a final "e" is silent unless it carries "-le" or follows a vowel.
    walked: 1, needed: 2, wanted: 2, makes: 1, verses: 2, places: 2,
    simple: 2, people: 2, made: 1, queue: 1,
  };
  for (const [word, n] of Object.entries(expected)) {
    assert.equal(syllables(word), n, `${word} should be ${n} syllable(s)`);
  }
});

test("syllables ignores case, punctuation and empty input", () => {
  assert.equal(syllables("Prophet,"), syllables("prophet"));
  assert.equal(syllables("al-Sa'di"), syllables("alsadi"));
  assert.equal(syllables(""), 0);
  assert.equal(syllables(null), 0);
  assert.equal(syllables("2255"), 0, "a token with no letters has no syllables");
});

test("the heuristic's known misses stay put", () => {
  // A vowel-group count cannot get these right without a pronouncing dictionary.
  // They are pinned so a change to the heuristic is a deliberate one: each is off
  // by one syllable, which moves a 60-word section's grade by well under 0.2.
  assert.equal(syllables("intermediaries"), 5); // in-ter-me-di-ar-ies
  assert.equal(syllables("created"), 2); // cre-at-ed
  assert.equal(syllables("business"), 3); // biz-ness
});

test("sentences splits on terminal punctuation and keeps abbreviations whole", () => {
  assert.deepEqual(sentences("The sky is blue. The sea is not! Is it? Yes."), [
    "The sky is blue.", "The sea is not!", "Is it?", "Yes.",
  ]);
  assert.deepEqual(sentences('He said "stop." Then he left.'), ['He said "stop."', "Then he left."]);
  assert.deepEqual(sentences("Dr. Watt wrote it."), ["Dr. Watt wrote it."]);
  assert.deepEqual(sentences("W. Montgomery Watt wrote it."), ["W. Montgomery Watt wrote it."]);
});

test("sentences never loses text that has no full stop", () => {
  assert.deepEqual(sentences("no full stop here"), ["no full stop here"]);
  assert.deepEqual(sentences("   "), []);
  assert.deepEqual(sentences(null), []);
});

test("wordsOf drops tokens with no letter or digit", () => {
  assert.deepEqual(wordsOf("a stray - dash, and 7 words"), ["a", "stray", "dash", "and", "7", "words"]);
  assert.deepEqual(wordsOf(""), []);
});

test("the Flesch-Kincaid grade follows the published formula", () => {
  // 0.39 * (words/sentences) + 11.8 * (syllables/words) - 15.59
  const text = "The cat sat on the mat. The dog ran away.";
  const r = readability(text);
  assert.equal(r.words, 10);
  assert.equal(r.sentences, 2);
  const expected = 0.39 * (r.words / r.sentences) + 11.8 * (r.syllables / r.words) - 15.59;
  assert.equal(r.grade, Math.round(Math.max(0, expected) * 10) / 10);
  assert.equal(r.wordsPerSentence, 5);
});

test("plain prose scores below the target and dense prose above it", () => {
  const plain =
    "God is one. He is not made of anything. He has no father and no children. " +
    "No one is like him at all. Everyone needs him, and he needs no one.";
  const dense =
    "The apodictic methodology of apophatic predication instantiated herein systematically " +
    "forecloses anthropomorphic conceptualisation, insofar as every affirmative attribution " +
    "would necessarily derive from contingent creaturely particularity.";
  assert.ok(fleschKincaidGrade(plain) < 6, `plain prose scored ${fleschKincaidGrade(plain)}`);
  assert.ok(fleschKincaidGrade(dense) > 20, `dense prose scored ${fleschKincaidGrade(dense)}`);
  assert.ok(meanSentenceLength(plain) < 12);
  assert.ok(meanSentenceLength(dense) > 20);
});

test("splitting one long sentence in two lowers the grade without changing a word", () => {
  const one = "The surah removes every picture a reader might form of God, because each such " +
    "picture is borrowed from something created, and so the description can never settle.";
  const two = "The surah removes every picture a reader might form of God. Each such picture is " +
    "borrowed from something created. So the description can never settle.";
  assert.ok(fleschKincaidGrade(two) < fleschKincaidGrade(one) - 2);
});

test("empty text scores zero rather than NaN", () => {
  for (const value of ["", "   ", null, undefined]) {
    const r = readability(value);
    assert.deepEqual(r, {
      words: 0, sentences: 0, syllables: 0, wordsPerSentence: 0, syllablesPerWord: 0, grade: 0,
    });
  }
});

test("a grade never reports as negative", () => {
  assert.equal(fleschKincaidGrade("Go now."), 0);
});

test("longWords finds the Latinate words the rewrite is meant to replace", () => {
  const text = "The commentators discuss intercession and accountability at length.";
  assert.deepEqual(longWords(text), ["commentators", "intercession", "accountability"]);
  assert.deepEqual(longWords("a short plain line of text"), []);
  assert.ok(longWords(text, { minSyllables: 6 }).includes("accountability"));
});
