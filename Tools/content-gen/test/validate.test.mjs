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
/** The same unit after the simplify pass: plain prose, an explainEasier line, meta.simplified. */
const simplifiedBase = JSON.parse(
  fs.readFileSync(path.join(here, "fixtures", "simplified-112.json"), "utf8"),
);
const THEMES = JSON.parse(fs.readFileSync(path.join(here, "..", "out", "themes.json"), "utf8")).themes;
const ctx = {
  quran: loadQuran(),
  passages: loadPassages(),
  themeIds: new Set(THEMES.map((t) => t.id)),
  themeTitles: new Map(THEMES.map((t) => [t.id, t.title])),
};

const run = (mutate = (s) => s) => {
  const study = mutate(structuredClone(base));
  return validateRecords([{ key: study.key, study, source: "fixture" }], ctx);
};
const runSimplified = (mutate = (s) => s) => {
  const study = mutate(structuredClone(simplifiedBase));
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

test("rejects a reference that points at the passage itself", () => {
  const res = run((s) => {
    s.exploreFurther[0] = s.key;
    return s;
  });
  assert.ok(errorsMatching(res, /exploreFurther\[0\] points at the passage itself/).length === 1);
});

// --- keyTerms[].arabic must be copied out of the unit's own Uthmani text ------

test("rejects a key term that does not occur in the passage", () => {
  const res = run((s) => {
    s.keyTerms[0].arabic = "\u0635\u064e\u0628\u0652\u0631"; // sabr, nowhere in surah 112
    return s;
  });
  assert.ok(errorsMatching(res, /keyTerms\[0\]\.arabic does not occur in 112:1-4/).length === 1);
});

test("rejects a key term retyped with a bare alef for the alef wasla", () => {
  const res = run((s) => {
    s.keyTerms[1].arabic = s.keyTerms[1].arabic.replace("\u0671", "\u0627");
    return s;
  });
  const hit = errorsMatching(res, /keyTerms\[1\]\.arabic is not copied verbatim from 112:1-4/);
  assert.equal(hit.length, 1);
  // The message names the passage's own spelling, so the fix is a paste.
  assert.match(hit[0], /the text has \u0671/);
});

test("rejects a key term retyped with a plain alef for the superscript alef", () => {
  // 2:200 spells "your rites" with a dagger alef on a tatweel carrier.
  const study = structuredClone(base);
  study.key = "2:200";
  study.surah = 2;
  study.start = 200;
  study.end = 200;
  study.crossReferences[1].ref = "2:255";
  const withTerm = (arabic) => {
    const s = structuredClone(study);
    s.keyTerms = [{ ...s.keyTerms[0], arabic }, s.keyTerms[1], s.keyTerms[2]];
    return validateRecords([{ key: s.key, study: s, source: "fixture" }], ctx);
  };
  assert.equal(
    errorsMatching(withTerm("\u0645\u064e\u0651\u0646\u064e\u0640\u0670\u0633\u0650\u0643\u064e\u0643\u064f\u0645\u0652"), /keyTerms\[0\]\.arabic/).length,
    0,
    "the passage's own spelling must pass",
  );
  assert.equal(
    errorsMatching(withTerm("\u0645\u064e\u0651\u0646\u064e\u0627\u0633\u0650\u0643\u064e\u0643\u064f\u0645\u0652"), /keyTerms\[0\]\.arabic is not copied verbatim/).length,
    1,
    "a plain alef for the dagger alef is a retype, not an absence",
  );
});

test("does not count the Bismillah prefix as part of the passage", () => {
  // Tanzil prefixes ayah 1 of surah 112 with the Bismillah; it is not the ayah.
  const res = run((s) => {
    s.keyTerms[0].arabic = "\u0671\u0644\u0631\u064e\u0651\u062d\u0652\u0645\u064e\u0640\u0670\u0646\u0650";
    return s;
  });
  assert.ok(errorsMatching(res, /keyTerms\[0\]\.arabic does not occur in 112:1-4/).length === 1);
});

// --- theme / themeId agreement ------------------------------------------------

test("rejects a theme that is not its themeId's title", () => {
  const res = run((s) => {
    s.theme = "The Living Earth";
    return s;
  });
  const hit = errorsMatching(res, /is not the title of themeId "sincerity"/);
  assert.equal(hit.length, 1);
  assert.match(hit[0], /themes\.json says "Sincerity"/);
});

// --- references may not lead back into the unit -------------------------------

test("rejects a reference that overlaps the passage's own ayat", () => {
  const res = run((s) => {
    s.exploreFurther[0] = "112:3-4";
    return s;
  });
  assert.ok(errorsMatching(res, /exploreFurther\[0\] overlaps the passage's own ayat: 112:3-4/).length === 1);
});

test("allows a reference to a different surah with the same ayah numbers", () => {
  const res = run((s) => {
    s.exploreFurther[0] = "113:1-4";
    return s;
  });
  assert.deepEqual(res.errors, []);
});

// --- script hygiene in prose --------------------------------------------------

test("rejects non-Latin, non-Arabic script in prose", () => {
  const res = run((s) => {
    s.meaning = s.meaning.replace("God is one", "God is \u0441\u0432\u0435\u0442 one");
    return s;
  });
  const hit = errorsMatching(res, /meaning contains non-Latin script/);
  assert.equal(hit.length, 1);
  assert.match(hit[0], /U\+0441/);
});

test("rejects non-Latin script inside a key-term note", () => {
  const res = run((s) => {
    s.keyTerms[0].note = s.keyTerms[0].note.replace("Not the", "Not the \u03bb\u03cc\u03b3\u03bf\u03c2");
    return s;
  });
  assert.ok(errorsMatching(res, /keyTerms\[0\]\.note contains non-Latin script/).length === 1);
});

test("accepts Latin letters carrying diacritics in prose", () => {
  const res = run((s) => {
    s.meaning = s.meaning.replace("The commentators", "Al-Sa\u2018d\u012b and the commentators");
    return s;
  });
  assert.deepEqual(res.errors, []);
});

// --- near-duplicate detection covers didYouKnow and applyIt -------------------

const twoRecords = (mutate) => {
  const a = structuredClone(base);
  const b = structuredClone(base);
  b.key = "113:1-5";
  b.surah = 113;
  b.start = 1;
  b.end = 5;
  b.keyTerms = structuredClone(base.keyTerms);
  mutate(b);
  return validateRecords(
    [
      { key: a.key, study: a, source: "a" },
      { key: b.key, study: b, source: "b" },
    ],
    ctx,
  );
};

test("flags a didYouKnow fact reused in another unit", () => {
  const res = twoRecords((b) => {
    b.meaning = "A short surah of refuge asks for shelter from what the dawn uncovers. " +
      "The request is placed in the mouth of the reader rather than described, which is why " +
      "the tradition pairs it with the surah that follows. Commentators read the four named " +
      "harms as a widening circle, from the world at large to the person standing next to you, " +
      "and they decline to rank them against each other in any order of severity at all here.";
  });
  assert.ok(errorsMatching(res, /didYouKnow is a near-duplicate of 113:1-5/).length === 1);
});

test("flags an applyIt exercise reused in another unit", () => {
  const res = twoRecords((b) => {
    b.meaning = "A short surah of refuge asks for shelter from what the dawn uncovers. " +
      "The request is placed in the mouth of the reader rather than described, which is why " +
      "the tradition pairs it with the surah that follows. Commentators read the four named " +
      "harms as a widening circle, from the world at large to the person standing next to you, " +
      "and they decline to rank them against each other in any order of severity at all here.";
    b.didYouKnow = "The surah names four harms in four clauses, and the classical recitation " +
      "manuals treat the pause after each as optional, which is unusual for a surah of this " +
      "length. Reciters differ on whether the final clause is one breath or two, and both " +
      "readings are recorded without preference in the standard manuals of the tradition.";
  });
  assert.ok(errorsMatching(res, /applyIt is a near-duplicate of 113:1-5/).length === 1);
});


// --- readability -------------------------------------------------------------

const DENSE =
  "The apodictic methodology of apophatic predication instantiated herein systematically " +
  "forecloses anthropomorphic conceptualisation, insofar as every affirmative attribution " +
  "would necessarily derive from contingent creaturely particularity, and the consequent " +
  "definitional residuum remains nonetheless recitable by an unlettered child of the era.";

test("a simplified unit passes the readability targets", () => {
  const res = runSimplified();
  assert.deepEqual(res.errors, []);
  assert.deepEqual(errorsMatching(res, /readability/), []);
});

test("readability misses are errors once meta.simplified is set", () => {
  const res = runSimplified((s) => {
    s.meaning = DENSE;
    return s;
  });
  const hits = errorsMatching(res, /readability above target/);
  assert.equal(hits.length, 1, res.errors.join("\n"));
  assert.match(hits[0], /meaning grade \d+(\.\d+)? > 8\.5/);
  assert.match(hits[0], /meaning \d+(\.\d+)? words\/sentence > 20/);
});

test("the same miss is only a warning on a unit the simplify pass has not seen", () => {
  const res = run((s) => {
    s.meaning = DENSE;
    return s;
  });
  assert.deepEqual(errorsMatching(res, /readability/), []);
  assert.equal(res.warnings.filter((w) => /readability above target/.test(w)).length, 1);
});

test("each section is held to its own ceiling", () => {
  // didYouKnow and historicalContext are allowed 9.5; the rest 8.5.
  // Grade 9.1: over lifeInProphetsTime's 8.5 ceiling, under historicalContext's 9.5.
  const between =
    "The surah came down in Mecca, and the sources report a question about the lineage of " +
    "God. Arabian gods carried a family line and a home region, so the question was a normal " +
    "one to ask. The answer refuses the whole category rather than naming a better ancestor.";
  const res = runSimplified((s) => {
    s.historicalContext = between;
    s.lifeInProphetsTime = between;
    return s;
  });
  const hits = errorsMatching(res, /readability above target/);
  assert.equal(hits.length, 1, hits.join("\n"));
  assert.match(hits[0], /lifeInProphetsTime grade/);
  assert.ok(!/historicalContext grade/.test(hits[0]), hits[0]);
});

test("a long average sentence fails even when the words are short", () => {
  const rambling =
    "He is one and he is the one everyone turns to and he needs nothing at all from anyone, " +
    "and he did not father a child and no one fathered him, and there is no one at all like " +
    "him in any way that a person could ever think of or point to or name or hold in mind.";
  const res = runSimplified((s) => {
    s.applyIt = rambling;
    return s;
  });
  const hits = errorsMatching(res, /readability above target/);
  assert.equal(hits.length, 1, hits.join("\n"));
  assert.match(hits[0], /applyIt \d+(\.\d+)? words\/sentence > 20/);
});

// --- explainEasier -----------------------------------------------------------

test("explainEasier is required once a unit is simplified", () => {
  const res = runSimplified((s) => {
    delete s.explainEasier;
    return s;
  });
  assert.equal(errorsMatching(res, /explainEasier missing/).length, 1);
});

test("explainEasier is optional on a unit the simplify pass has not seen", () => {
  const res = run();
  assert.ok(!("explainEasier" in base));
  assert.deepEqual(errorsMatching(res, /explainEasier/), []);
});

test("explainEasier is held to 25-50 words", () => {
  const short = runSimplified((s) => {
    s.explainEasier = "God is one and nothing is like him.";
    return s;
  });
  assert.equal(errorsMatching(short, /explainEasier is 8 words, must be 25-50/).length, 1);

  const long = runSimplified((s) => {
    s.explainEasier = `${s.explainEasier} ${"and he is still one ".repeat(6)}`;
    return s;
  });
  assert.equal(errorsMatching(long, /explainEasier is \d+ words, must be 25-50/).length, 1);
});

test("explainEasier must read at grade 6 or below", () => {
  const res = runSimplified((s) => {
    s.explainEasier =
      "This passage establishes the doctrine of divine omniscience and absolute sovereignty, " +
      "articulating a theological proposition regarding the incomparability of the creator.";
    return s;
  });
  assert.equal(errorsMatching(res, /explainEasier grade \d+(\.\d+)? > 6/).length, 1);
});

test("explainEasier may not carry Arabic script or a ruling", () => {
  const arabic = runSimplified((s) => {
    s.explainEasier = s.explainEasier.replace("God is one", "God is أَحَدٌ one");
    return s;
  });
  assert.equal(errorsMatching(arabic, /explainEasier contains Arabic script/).length, 1);

  const ruling = runSimplified((s) => {
    s.explainEasier = `You must say this line tonight. ${s.explainEasier}`;
    return s;
  });
  assert.ok(errorsMatching(ruling, /explainEasier: prescriptive ruling/).length === 1);
});

test("a structural problem in explainEasier is an error even before the simplify pass", () => {
  const res = run((s) => {
    s.explainEasier = "Too short.";
    return s;
  });
  assert.equal(errorsMatching(res, /explainEasier is 2 words, must be 25-50/).length, 1);
});
