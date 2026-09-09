import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadQuran } from "../lib/data.mjs";
import { selectUnits } from "../lib/units.mjs";
import { PROMPT_VERSION } from "../lib/prompt.mjs";
import { segment, loadNamedPassages } from "../segment-passages.mjs";
import { unitKey } from "../lib/data.mjs";
import { cachePath } from "../build-requests.mjs";
import { assembleStudy, loadCache } from "../assemble.mjs";
import {
  AUTHOR_MODEL, unitsFromPassages, ensureUnits, selectAuthorUnits, todoUnits,
  cachedKeys, assembledKeys, promptFor, normaliseBody, validateBodies, writeRecord,
  statusReport,
} from "../lib/author.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(fs.readFileSync(path.join(here, "fixtures", "valid-112.json"), "utf8"));
/** The fixture is a fully assembled study; an author writes only these fields. */
const body = () => normaliseBody(structuredClone(fixture), fixture.key).body;

const quran = loadQuran();
ensureUnits();

/** A unit no authoring wave will be working on, so the cache round-trip is safe. */
const scratchUnit = selectUnits("all").find((u) => u.tier === "standard" && u.surah > 100);
const TEST_MODEL = "author-test-model";

test("the unit list rebuilt from passages.json matches the segmenter", () => {
  const named = loadNamedPassages(quran.byNumber);
  const expected = segment(quran, named, { minOwnWords: 24, maxAyat: 5, maxWords: 60 });
  const actual = unitsFromPassages(quran);
  assert.equal(actual.length, expected.length);
  assert.deepEqual(
    actual.map((u) => u.key),
    expected.map((u) => unitKey(u.surah, u.start, u.end)),
  );
  assert.deepEqual(
    actual.map((u) => u.words),
    expected.map((u) => u.words),
  );
});

test("selectAuthorUnits accepts an explicit keys: slice", () => {
  const units = selectAuthorUnits("keys:112:1-4,1:1-7");
  assert.deepEqual(units.map((u) => u.key), ["112:1-4", "1:1-7"]);
  assert.throws(() => selectAuthorUnits("keys:2:1"), /not a unit key/);
});

test("todo excludes cached and assembled keys", () => {
  const all = todoUnits({ only: "discover", done: new Set() });
  assert.ok(all.length > 300, `only ${all.length} discover units`);

  const skipped = all.slice(0, 3).map((u) => u.key);
  const rest = todoUnits({ only: "discover", done: new Set(skipped) });
  assert.equal(rest.length, all.length - skipped.length);
  for (const k of skipped) assert.ok(!rest.some((u) => u.key === k), `${k} still listed`);

  // …and the real lookup is the union of work/cache and the committed shards.
  const done = new Set([...cachedKeys(), ...assembledKeys()]);
  for (const u of todoUnits({ only: "discover" })) assert.ok(!done.has(u.key));
});

test("todo honours --limit and reports word counts", () => {
  const units = todoUnits({ only: "discover", limit: 4, done: new Set() });
  assert.equal(units.length, 4);
  for (const u of units) {
    assert.ok(u.words > 0);
    assert.equal(u.ayatCount, u.end - u.start + 1);
    assert.equal(u.tier, "discover");
  }
});

test("prompt renders the cached system blocks and the unit's user turn", () => {
  const { system, user } = promptFor("112:1-4");
  assert.match(system, /# Hard rules/);
  assert.match(system, /# Theme list/);
  assert.match(system, /sincerity — Sincerity/);
  assert.match(user, /This unit is 112:1-4/);
  assert.match(user, /Talal Itani/);
  assert.ok(!user.includes("{{"), "user turn still has unrendered placeholders");
});

test("normaliseBody strips assemble-stamped fields and flags mismatches", () => {
  const { body: clean, problems } = normaliseBody(structuredClone(fixture), fixture.key);
  assert.deepEqual(problems, []);
  for (const f of ["key", "surah", "start", "end", "tier", "meta"]) {
    assert.ok(!(f in clean), `${f} should not survive into the body`);
  }
  assert.equal(normaliseBody({ ...fixture, key: "1:1-7" }, fixture.key).problems.length, 1);
  assert.ok(normaliseBody({ ...fixture, nonsense: 1 }, fixture.key).problems.some((p) => /unknown field/.test(p)));
});

test("write accepts a valid body", () => {
  const res = validateBodies([{ key: fixture.key, body: body() }], { withCorpus: false });
  assert.deepEqual(res.get(fixture.key).errors, []);
});

test("write rejects an invalid body", () => {
  const broken = body();
  broken.applyIt = "You must pray tonight.";
  broken.crossReferences[0].ref = "112:9";
  broken.themeId = "not-a-theme";
  const res = validateBodies([{ key: fixture.key, body: broken }], { withCorpus: false }).get(fixture.key);
  assert.ok(res.errors.some((e) => /applyIt is \d+ words/.test(e)));
  assert.ok(res.errors.some((e) => /prescriptive ruling/.test(e)));
  assert.ok(res.errors.some((e) => /out of bounds: 112:9/.test(e)));
  assert.ok(res.errors.some((e) => /unknown themeId/.test(e)));
});

test("validation findings are attributed to the candidate, not the corpus", () => {
  const res = validateBodies([{ key: fixture.key, body: body() }]);
  for (const msg of [...res.get(fixture.key).errors, ...res.get(fixture.key).warnings]) {
    assert.ok(msg.startsWith(`${fixture.key}: `), msg);
  }
});

test("a written record has poll-batch's shape and round-trips through assembleStudy", (t) => {
  const key = scratchUnit.key;
  const file = cachePath(TEST_MODEL, key);
  t.after(() => fs.rmSync(file, { force: true }));

  const { record } = writeRecord(key, body(), { model: TEST_MODEL, author: "unit-test" });
  assert.deepEqual(Object.keys(record).sort(), [
    "author", "body", "key", "model", "promptVersion", "receivedAt", "usage",
  ]);
  assert.equal(record.promptVersion, PROMPT_VERSION);
  assert.equal(record.usage, null);
  assert.ok(!Number.isNaN(Date.parse(record.receivedAt)));

  const onDisk = JSON.parse(fs.readFileSync(file, "utf8"));
  assert.deepEqual(onDisk, record);

  const study = assembleStudy(onDisk, scratchUnit);
  assert.equal(study.key, key);
  assert.equal(study.surah, scratchUnit.surah);
  assert.equal(study.start, scratchUnit.start);
  assert.equal(study.end, scratchUnit.end);
  assert.equal(study.tier, scratchUnit.tier);
  assert.deepEqual(study.meta, {
    model: TEST_MODEL,
    promptVersion: PROMPT_VERSION,
    generatedAt: record.receivedAt,
    reviewed: false,
  });
  assert.equal(study.meaning, fixture.meaning);

  // assemble.mjs must be able to find it by model.
  assert.ok(loadCache({ model: TEST_MODEL }).some((c) => c.key === key));
  assert.ok(cachedKeys({ model: TEST_MODEL }).has(key));
});

test("status counts units, cache and shards", () => {
  const s = statusReport();
  assert.equal(s.units, selectUnits("all").length);
  assert.equal(s.discover, selectUnits("discover").length);
  assert.equal(s.discoverAssembled + s.discoverCachedOnly + s.discoverRemaining.length, s.discover);
  assert.ok(s.assembled >= 0 && s.cached >= 0);
});

test("the default author model is the one the pipeline records", () => {
  assert.equal(AUTHOR_MODEL, "claude-opus-5");
});
