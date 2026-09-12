import test from "node:test";
import assert from "node:assert/strict";
import { loadQuran } from "../lib/data.mjs";
import {
  nfc, looseArabic, unitUthmani, exactSpanFor, stripBasmala, BASMALA,
} from "../lib/arabic.mjs";

const quran = loadQuran();

test("the loose form folds the tatweel carrier under a dagger alef", () => {
  // 13:19 spells "the kernels" with a tatweel carrying U+0670.
  const fromText = "ٱلْأَلْبَـٰبِ";
  const retyped = "ٱلْأَلْبَٰبِ";
  assert.notEqual(nfc(fromText), nfc(retyped));
  assert.equal(looseArabic(fromText), looseArabic(retyped));
});

test("the loose form reads the superscript alef as an alef", () => {
  assert.equal(
    looseArabic("قَـٰسِيَةً"), // 5:13 spelling
    looseArabic("قَاسِيَةً"), // hand-typed
  );
});

test("the loose form folds alef wasla, alef maqsura and ta marbuta", () => {
  assert.equal(looseArabic("ٱل"), looseArabic("ال"));
  assert.equal(looseArabic("موسى"), looseArabic("موسي"));
  assert.equal(looseArabic("رحمة"), looseArabic("رحمه"));
});

test("exactSpanFor returns the passage's own spelling", () => {
  const text = unitUthmani(quran, { surah: 13, start: 19, end: 19 });
  const retyped = "ٱلْأَلْبَٰبِ";
  const span = exactSpanFor(text, retyped);
  assert.ok(text.includes(span), "the span must be a literal substring of the passage");
  assert.equal(looseArabic(span), looseArabic(retyped));
  assert.notEqual(span, retyped);
});

test("exactSpanFor prefers a whole token over a prefix of a longer one", () => {
  // 2:270 holds both نَذَرْتُم and نَّذْرٍ; only the second is the noun "a vow".
  const text = unitUthmani(quran, { surah: 2, start: 270, end: 271 });
  const span = exactSpanFor(text, "نَذْرٍ");
  assert.ok(text.includes(` ${span} `) || text.endsWith(` ${span}`), `span "${span}" is not a whole token`);
});

test("stripBasmala removes the prefix from ayah 1 but leaves surahs 1 and 9", () => {
  const raw = quran.uthmani(112, 1);
  assert.ok(nfc(raw).startsWith(BASMALA), "Tanzil prefixes 112:1 with the Bismillah");
  assert.ok(!stripBasmala(raw, 112, 1).startsWith(BASMALA));
  assert.equal(stripBasmala(quran.uthmani(1, 1), 1, 1), nfc(quran.uthmani(1, 1)));
  assert.equal(stripBasmala(quran.uthmani(9, 1), 9, 1), nfc(quran.uthmani(9, 1)));
  assert.equal(stripBasmala(raw, 112, 2), nfc(raw), "only ayah 1 carries the prefix");
});

test("unitUthmani joins the unit's ayat without the Bismillah", () => {
  const text = unitUthmani(quran, { surah: 112, start: 1, end: 4 });
  assert.ok(!text.includes(BASMALA));
  assert.ok(text.includes("ٱلصَّمَدُ")); // al-Samad, 112:2
});
