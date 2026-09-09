import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadQuran } from "../lib/data.mjs";
import { validateRecords } from "../validate.mjs";
import { loadPassages } from "../lib/units.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const base = JSON.parse(fs.readFileSync(path.join(here, "fixtures", "valid-112.json"), "utf8"));
const ctx = {
  quran: loadQuran(),
  passages: loadPassages(),
  themeIds: new Set(
    JSON.parse(fs.readFileSync(path.join(here, "..", "out", "themes.json"), "utf8")).themes.map((t) => t.id),
  ),
};

const run = (mutate = (s) => s) => {
  const study = mutate(structuredClone(base));
  return validateRecords([{ key: study.key, study, source: "fixture" }], ctx);
};
const errorsMatching = (res, re) => res.errors.filter((e) => re.test(e));

test("a well-formed study passes with no errors", () => {
  const res = run();
  assert.deepEqual(res.errors, []);
});

test("rejects Arabic script in English prose fields", () => {
  const res = run((s) => {
    s.meaning = s.meaning.replace("God is one", "God is ٱلصَّمَد one");
    return s;
  });
  assert.ok(errorsMatching(res, /meaning contains Arabic script/).length === 1);
});

test("rejects a keyTerm whose arabic field is a transliteration", () => {
  const res = run((s) => {
    s.keyTerms[0].arabic = "ahad";
    return s;
  });
  assert.ok(errorsMatching(res, /keyTerms\[0\]\.arabic is not Arabic script/).length === 1);
  assert.ok(errorsMatching(res, /keyTerms\[0\]\.arabic contains Latin letters/).length === 1);
});

test("rejects cross-references outside the surah's ayah count", () => {
  const res = run((s) => {
    s.crossReferences[0].ref = "112:9"; // surah 112 has 4 ayat
    return s;
  });
  assert.ok(errorsMatching(res, /crossReferences\[0\]\.ref out of bounds: 112:9/).length === 1);
});

test("rejects exploreFurther pointing at a surah that does not exist", () => {
  const res = run((s) => {
    s.exploreFurther[0] = "115:1";
    return s;
  });
  assert.ok(errorsMatching(res, /exploreFurther\[0\] out of bounds/).length === 1);
});

test("enforces the word bounds from x-wordBounds", () => {
  const res = run((s) => {
    s.applyIt = "Think about it today.";
    return s;
  });
  assert.ok(errorsMatching(res, /applyIt is 4 words, must be 30-80/).length === 1);
});

test("rejects legal-ruling language", () => {
  const res = run((s) => {
    s.applyIt = s.applyIt.replace("Notice today", "You must notice today");
    return s;
  });
  assert.ok(errorsMatching(res, /prescriptive ruling/).length >= 1);
});

test("rejects sectarian framing", () => {
  const res = run((s) => {
    s.theologicalSignificance = s.theologicalSignificance.replace("Later theology", "Later Ash'ari theology");
    return s;
  });
  assert.ok(errorsMatching(res, /sectarian framing/).length >= 1);
});

test('requires the honorific when Muhammad is named', () => {
  const res = run((s) => {
    s.historicalContext = s.historicalContext.replace("the Prophet Muhammad (peace be upon him)", "Muhammad");
    return s;
  });
  assert.ok(errorsMatching(res, /without the honorific/).length === 1);
});

test('rejects "Allah" in English prose', () => {
  const res = run((s) => {
    s.meaning = s.meaning.replace("God is one", "Allah is one");
    return s;
  });
  assert.ok(errorsMatching(res, /use "God" in English prose/).length >= 1);
});

test("rejects a key that is not a segmented unit", () => {
  const res = run((s) => {
    s.key = "112:2";
    s.start = 2;
    return s;
  });
  assert.ok(errorsMatching(res, /not a unit key/).length === 1);
});

test("rejects an unknown themeId", () => {
  const res = run((s) => {
    s.themeId = "made-up-theme";
    return s;
  });
  assert.ok(errorsMatching(res, /unknown themeId/).length === 1);
});

test("flags near-duplicate meaning sections across records", () => {
  const a = structuredClone(base);
  const b = structuredClone(base);
  b.key = "113:1-5";
  b.surah = 113;
  b.start = 1;
  b.end = 5;
  const res = validateRecords(
    [
      { key: a.key, study: a, source: "a" },
      { key: b.key, study: b, source: "b" },
    ],
    ctx,
  );
  assert.ok(errorsMatching(res, /near-duplicate/).length >= 1);
});

test("warns when a reference points at the passage itself", () => {
  const res = run((s) => {
    s.exploreFurther[0] = s.key;
    return s;
  });
  assert.deepEqual(res.errors, []);
  assert.ok(res.warnings.some((w) => /points at the passage itself/.test(w)));
});
