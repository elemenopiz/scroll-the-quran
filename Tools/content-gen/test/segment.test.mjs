import test from "node:test";
import assert from "node:assert/strict";
import { loadQuran, words, parseKey, refInBounds, unitKey } from "../lib/data.mjs";
import { segment, loadNamedPassages, DEFAULTS } from "../segment-passages.mjs";
import { selectUnits, discoverKeys, loadPassages } from "../lib/units.mjs";
import { encodeCustomId, decodeCustomId, logicalCustomId, buildOutputSchema, render } from "../lib/prompt.mjs";

const quran = loadQuran();
const named = loadNamedPassages(quran.byNumber);
const units = segment(quran, named, DEFAULTS);

test("segmentation covers every ayah exactly once", () => {
  const seen = new Set();
  for (const u of units) {
    for (let a = u.start; a <= u.end; a++) {
      const k = `${u.surah}:${a}`;
      assert.ok(!seen.has(k), `${k} covered twice`);
      seen.add(k);
    }
  }
  assert.equal(seen.size, 6236);
});

test("no unit spans a surah boundary and none exceeds the envelope", () => {
  for (const u of units) {
    assert.ok(u.end >= u.start);
    assert.ok(u.end <= quran.byNumber.get(u.surah).ayahCount);
    if (!u.named) {
      assert.ok(u.end - u.start + 1 <= DEFAULTS.maxAyat, `${unitKey(u.surah, u.start, u.end)} too many ayat`);
    }
  }
});

test("every named passage survives as exactly one unit", () => {
  const keys = new Set(units.map((u) => unitKey(u.surah, u.start, u.end)));
  for (const list of named.values()) {
    for (const n of list) assert.ok(keys.has(unitKey(n.surah, n.start, n.end)), `${n.name} was split`);
  }
});

test("an ayah of 12+ words that is not inside a named passage stands alone", () => {
  const byStart = new Map(units.map((u) => [`${u.surah}:${u.start}`, u]));
  const u = byStart.get("2:6");
  assert.ok(u);
  if (words(quran.english(2, 6)) >= DEFAULTS.minOwnWords) assert.equal(u.end, u.start);
});

test("passages.json maps all 6,236 ayat to unit keys", () => {
  const passages = loadPassages();
  assert.equal(Object.keys(passages).length, 6236);
  assert.equal(passages["2:255"], "2:255");
  assert.equal(passages["94:5"], "94:1-8");
});

test("every discover seed reference resolves to a unit", () => {
  const keys = discoverKeys();
  assert.ok(keys.length >= 300, `only ${keys.length} discover units`);
  const all = new Set(selectUnits("all").map((u) => u.key));
  for (const k of keys) assert.ok(all.has(k), `${k} is not a unit`);
});

test("discover selection tags its units and spans the whole Quran", () => {
  const sel = selectUnits("discover");
  assert.ok(sel.every((u) => u.tier === "discover"));
  const surahs = new Set(sel.map((u) => u.surah));
  assert.ok(surahs.size > 90, `only ${surahs.size} surahs represented`);
});

test("custom ids round-trip through the wire encoding", () => {
  for (const key of ["2:255", "94:5-6", "1:1-7"]) {
    const id = encodeCustomId("claude-opus-5", key);
    assert.match(id, /^[A-Za-z0-9_-]{1,64}$/);
    assert.deepEqual(decodeCustomId(id), { promptVersion: "p1", model: "claude-opus-5", key });
    assert.equal(logicalCustomId("claude-opus-5", key), `p1:claude-opus-5:${key}`);
  }
});

test("the structured-output schema drops validation-only keywords", () => {
  const s = buildOutputSchema();
  const json = JSON.stringify(s);
  assert.equal(s.additionalProperties, false);
  assert.ok(!json.includes("pattern"));
  assert.ok(!json.includes("minLength"));
  assert.ok(!json.includes("x-"));
  assert.ok(s.required.includes("keyTerms"));
  assert.ok(!s.required.includes("meta"), "meta is stamped locally, not asked of the model");
});

test("the template renderer handles conditionals and comments", () => {
  const out = render("{{!-- c {{x}} --}}A {{a}}{{#if b}} B {{b}}{{/if}}", { a: "1", b: "" });
  assert.equal(out.trim(), "A 1");
  const out2 = render("A {{a}}{{#if b}} B {{b}}{{/if}}", { a: "1", b: "2" });
  assert.equal(out2.trim(), "A 1 B 2");
});

test("reference bounds checking rejects impossible ayat", () => {
  assert.ok(refInBounds("2:286", quran.byNumber));
  assert.ok(!refInBounds("2:287", quran.byNumber));
  assert.ok(!refInBounds("115:1", quran.byNumber));
  assert.equal(parseKey("94:5-6").end, 6);
});
