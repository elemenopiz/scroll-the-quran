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
  AUTHOR_MODEL, SIMPLIFY_VERSION, unitsFromPassages, ensureUnits, selectAuthorUnits, todoUnits,
  cachedKeys, assembledKeys, promptFor, normaliseBody, validateBodies, writeRecord,
  statusReport, rewriteTodoUnits, rewritePromptFor, checkRewriteFidelity, measureStudy,
  bodyOf, currentStudy, simplifiedKeys,
} from "../lib/author.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(fs.readFileSync(path.join(here, "fixtures", "valid-112.json"), "utf8"));
const simplifiedFixture = JSON.parse(
  fs.readFileSync(path.join(here, "fixtures", "simplified-112.json"), "utf8"),
);
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


// --- the simplify pass -------------------------------------------------------

/** The rewritten 112:1-4 body, reduced to the fields an author writes. */
const simplifiedBody = () => normaliseBody(structuredClone(simplifiedFixture), simplifiedFixture.key).body;

test("normaliseBody lets explainEasier through and still does not require it", () => {
  const { body: withField, problems: withProblems } = normaliseBody(
    structuredClone(simplifiedFixture),
    simplifiedFixture.key,
  );
  assert.deepEqual(withProblems, []);
  assert.equal(typeof withField.explainEasier, "string");

  const { body: without, problems } = normaliseBody(structuredClone(fixture), fixture.key);
  assert.deepEqual(problems, []);
  assert.ok(!("explainEasier" in without));
});

test("a rewrite validates against the readability targets as errors", () => {
  const clean = validateBodies([{ key: fixture.key, body: simplifiedBody() }], {
    withCorpus: false,
    simplified: SIMPLIFY_VERSION,
  });
  assert.deepEqual(clean.get(fixture.key).errors, []);

  // The unsimplified original is the thing the pass exists to fix, so it must fail
  // when it is offered as a rewrite and pass when it is not.
  const original = () => normaliseBody(structuredClone(fixture), fixture.key).body;
  const asRewrite = validateBodies([{ key: fixture.key, body: original() }], {
    withCorpus: false,
    simplified: SIMPLIFY_VERSION,
  }).get(fixture.key);
  assert.ok(asRewrite.errors.some((e) => /readability above target/.test(e)), asRewrite.errors.join("\n"));
  assert.ok(asRewrite.errors.some((e) => /explainEasier missing/.test(e)));

  const asAuthored = validateBodies([{ key: fixture.key, body: original() }], { withCorpus: false });
  assert.deepEqual(asAuthored.errors ?? [], []);
  assert.deepEqual(asAuthored.get(fixture.key).errors, []);
});

test("measureStudy scores every prose section against its own ceiling", () => {
  const m = measureStudy(simplifiedFixture);
  assert.deepEqual(m.over, []);
  assert.ok(m.hasExplainEasier);
  assert.deepEqual(
    m.sections.map((s) => s.field),
    [
      "meaning", "historicalContext", "lifeInProphetsTime", "didYouKnow",
      "theologicalSignificance", "applyIt", "explainEasier",
    ],
  );
  assert.equal(m.sections.find((s) => s.field === "explainEasier").ceiling, 6);
  assert.ok(m.worst > 0);

  const dense = structuredClone(simplifiedFixture);
  dense.meaning =
    "The apodictic methodology of apophatic predication instantiated herein systematically " +
    "forecloses anthropomorphic conceptualisation, insofar as every affirmative attribution " +
    "would necessarily derive from contingent creaturely particularity.";
  assert.deepEqual(measureStudy(dense).over, ["meaning"]);
});

test("checkRewriteFidelity holds the fields a rewrite may not move", () => {
  const key = "112:1-4";
  const ok = checkRewriteFidelity(key, simplifiedBody());
  assert.deepEqual(ok.errors, []);

  const moved = simplifiedBody();
  moved.themeId = "patience";
  moved.theme = "Patience in Trials";
  moved.keyTerms[0].arabic = "أحد";
  const res = checkRewriteFidelity(key, moved);
  assert.ok(res.errors.some((e) => /themeId changed/.test(e)), res.errors.join("\n"));
  assert.ok(res.errors.some((e) => /theme changed/.test(e)));
  assert.ok(res.errors.some((e) => /keyTerms\[\]\.arabic must stay verbatim/.test(e)));
});

test("checkRewriteFidelity warns when the references or the title drift", () => {
  const drifted = simplifiedBody();
  drifted.title = "Something Else Entirely";
  drifted.exploreFurther = ["1:1-7", "2:255"];
  const res = checkRewriteFidelity("112:1-4", drifted);
  assert.deepEqual(res.errors, []);
  assert.ok(res.warnings.some((w) => /title changed/.test(w)));
  assert.ok(res.warnings.some((w) => /exploreFurther points somewhere else/.test(w)));
});

test("currentStudy reads the committed shard and bodyOf reduces it to a writable body", () => {
  const { study, source } = currentStudy("112:1-4");
  assert.equal(study.key, "112:1-4");
  assert.match(source, /surah_112\.json$/);
  const body = bodyOf(study);
  assert.ok(!("key" in body) && !("meta" in body) && !("tier" in body));
  assert.equal(typeof body.meaning, "string");
});

test("rewrite-todo lists units that exist and have not been simplified", () => {
  const units = rewriteTodoUnits({ only: "discover" });
  assert.ok(units.length > 0);
  const simplified = simplifiedKeys();
  for (const u of units) {
    assert.ok(!simplified.has(u.key), `${u.key} is already simplified`);
    assert.equal(u.tier, "discover");
    assert.ok(u.worstGrade > 0);
    assert.ok(Array.isArray(u.over));
  }

  const skipped = units.slice(0, 2).map((u) => u.key);
  const rest = rewriteTodoUnits({ only: "discover", done: new Set(skipped) });
  assert.equal(rest.length, units.length - skipped.length);
  assert.equal(rewriteTodoUnits({ only: "discover", limit: 3 }).length, 3);
});

test("rewrite-todo never lists a unit that has not been authored yet", () => {
  const authored = assembledKeys();
  for (const u of rewriteTodoUnits({ only: "all", limit: 50 })) assert.ok(authored.has(u.key));
});

test("the rewrite prompt carries the rules, the passage, the scores and the body", () => {
  const { text, measurements } = rewritePromptFor("112:1-4");
  assert.match(text, /explainEasier/);
  assert.match(text, /# What must not change/);
  assert.match(text, /key: 112:1-4/);
  assert.match(text, /## The passage/);
  assert.match(text, /## What it measures today/);
  assert.match(text, /## The body to rewrite/);
  assert.ok(text.includes(JSON.stringify(bodyOf(currentStudy("112:1-4").study), null, 2)));
  assert.equal(measurements.sections.length >= 6, true);
});

test("rewritePromptFor refuses a unit that has no study yet", () => {
  const missing = rewriteTodoUnits({ only: "all" });
  const authored = new Set(missing.map((u) => u.key));
  const unwritten = selectUnits("all").find((u) => !authored.has(u.key) && !assembledKeys().has(u.key));
  if (!unwritten) return; // the corpus is complete; nothing to assert
  assert.throws(() => rewritePromptFor(unwritten.key), /no study yet/);
});

test("a cached rewrite stamps meta.simplified so validate holds it to the targets", (t) => {
  const key = scratchUnit.key;
  const file = cachePath(TEST_MODEL, key);
  t.after(() => fs.rmSync(file, { force: true }));

  const { record } = writeRecord(key, simplifiedBody(), {
    model: TEST_MODEL,
    author: "unit-test",
    simplified: SIMPLIFY_VERSION,
  });
  assert.equal(record.simplified, SIMPLIFY_VERSION);

  const study = assembleStudy(JSON.parse(fs.readFileSync(file, "utf8")), scratchUnit);
  assert.equal(study.meta.simplified, SIMPLIFY_VERSION);
  assert.equal(study.meta.author, "unit-test");
  assert.equal(typeof study.explainEasier, "string");
  assert.ok(simplifiedKeys({ model: TEST_MODEL }).has(key));

  // Field order: explainEasier sits after the nine sections and before meta.
  const keys = Object.keys(study);
  assert.ok(keys.indexOf("explainEasier") > keys.indexOf("exploreFurther"));
  assert.equal(keys.indexOf("explainEasier") + 1, keys.indexOf("meta"));
});

test("an ordinary authored record carries no simplify stamp", (t) => {
  const key = scratchUnit.key;
  const file = cachePath(TEST_MODEL, key);
  t.after(() => fs.rmSync(file, { force: true }));

  writeRecord(key, body(), { model: TEST_MODEL, author: "unit-test" });
  const record = JSON.parse(fs.readFileSync(file, "utf8"));
  assert.ok(!("simplified" in record));
  const study = assembleStudy(record, scratchUnit);
  assert.deepEqual(Object.keys(study.meta), ["model", "promptVersion", "generatedAt", "reviewed"]);
});
