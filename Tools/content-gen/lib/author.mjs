// Authoring mode: Deep Study bodies written by an Opus session agent instead of
// the Message Batches API.
//
// The batch path (build-requests -> submit-batch -> poll-batch) needs an
// Anthropic credential. When there is none, an Opus agent running inside a
// Claude Code session is the model: it reads the same prompt, writes the same
// JSON body, and drops it into `work/cache/` in exactly the shape poll-batch
// would have written. Everything downstream (validate, assemble) is unchanged.
//
// Nothing in this file talks to the network.
import fs from "node:fs";
import path from "node:path";
import { ROOT, OUT, WORK, loadQuran, parseKey, unitKey, words } from "./data.mjs";
import { loadPassages, discoverKeys, selectUnits } from "./units.mjs";
import { PROMPT_VERSION, buildSystem, buildUserTurn } from "./prompt.mjs";
import { loadNamedPassages } from "../segment-passages.mjs";
import { cacheDir, cachePath } from "../build-requests.mjs";
import { assembleStudy } from "../assemble.mjs";
import { validateRecords } from "../validate.mjs";
import { readability } from "./readability.mjs";

export const AUTHOR_MODEL = "claude-opus-5";
export const DEFAULT_AUTHOR = "opus-session";

const SCHEMA = JSON.parse(fs.readFileSync(path.join(ROOT, "schema", "study.schema.json"), "utf8"));
/** The fields an author actually writes; everything else is stamped by assemble. */
export const MODEL_FIELDS = SCHEMA["x-modelFields"];
/** Fields a body may carry but need not: `explainEasier`, written by the rewrite pass. */
export const OPTIONAL_MODEL_FIELDS = SCHEMA["x-optionalModelFields"] ?? [];
const STAMPED_FIELDS = new Set(["key", "surah", "start", "end", "tier", "meta"]);
/** Grade ceilings and the explainEasier bounds, read straight off the schema. */
export const READABILITY_TARGETS = SCHEMA["x-readability"];
/** The promptVersion a rewrite stamps into `meta.simplified`. */
export const SIMPLIFY_VERSION = PROMPT_VERSION;

const readJSON = (p) => JSON.parse(fs.readFileSync(p, "utf8"));

// --- units -------------------------------------------------------------------

/**
 * Rebuild the unit list from the committed `out/study/passages.json`.
 *
 * `work/units.jsonl` is gitignored, so a fresh checkout has no unit list, and
 * re-running `segment-passages.mjs` with its built-in defaults would segment at
 * a different threshold and overwrite the committed passages.json. passages.json
 * already fixes every unit boundary, so the working set can be derived from it
 * without touching committed content.
 */
export function unitsFromPassages(quran = loadQuran()) {
  const passages = loadPassages();
  const named = loadNamedPassages(quran.byNumber);
  const nameOf = new Map();
  for (const [surah, list] of named) {
    for (const n of list) nameOf.set(unitKey(surah, n.start, n.end), n.name);
  }

  const seen = new Set();
  const units = [];
  for (const key of Object.values(passages)) {
    if (seen.has(key)) continue;
    seen.add(key);
    const p = parseKey(key);
    let total = 0;
    for (let a = p.start; a <= p.end; a++) total += words(quran.english(p.surah, a));
    units.push({
      key,
      surah: p.surah,
      start: p.start,
      end: p.end,
      ayatCount: p.end - p.start + 1,
      words: total,
      named: nameOf.get(key) ?? null,
    });
  }
  units.sort((a, b) => a.surah - b.surah || a.start - b.start);
  return units;
}

/**
 * Guarantee `work/units.jsonl` exists, rebuilding it from passages.json when it
 * does not. Returns { path, rebuilt }.
 */
export function ensureUnits() {
  const file = path.join(WORK, "units.jsonl");
  if (fs.existsSync(file)) return { path: file, rebuilt: false };
  const units = unitsFromPassages();
  fs.mkdirSync(WORK, { recursive: true });
  fs.writeFileSync(file, units.map((u) => JSON.stringify(u)).join("\n") + "\n");
  return { path: file, rebuilt: true, count: units.length };
}

/** selectUnits plus a `keys:a,b,c` selector for claiming an explicit slice. */
export function selectAuthorUnits(only = "discover") {
  const m = /^keys:(.+)$/.exec(only ?? "");
  if (!m) return selectUnits(only);
  const wanted = m[1].split(",").map((k) => k.trim()).filter(Boolean);
  const byKey = new Map(selectUnits("all").map((u) => [u.key, u]));
  return wanted.map((k) => {
    const u = byKey.get(k);
    if (!u) throw new Error(`${k} is not a unit key (check out/study/passages.json)`);
    return u;
  });
}

// --- what is already done ----------------------------------------------------

/** Keys with a `work/cache` record, read from the filenames alone. */
export function cachedKeys({ model = null, promptVersion = PROMPT_VERSION } = {}) {
  const dir = cacheDir();
  if (!fs.existsSync(dir)) return new Set();
  const keys = new Set();
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith(".json")) continue;
    const parts = f.slice(0, -5).split("--");
    if (parts.length !== 3) continue;
    if (promptVersion && parts[0] !== promptVersion) continue;
    if (model && parts[1] !== model) continue;
    keys.add(parts[2].replace("_", ":"));
  }
  return keys;
}

/** Keys already committed in the `out/study/surah_NNN.json` shards. */
export function assembledKeys() {
  const dir = path.join(OUT, "study");
  if (!fs.existsSync(dir)) return new Set();
  const keys = new Set();
  for (const f of fs.readdirSync(dir)) {
    if (!/^surah_\d{3}\.json$/.test(f)) continue;
    for (const s of readJSON(path.join(dir, f)).studies ?? []) keys.add(s.key);
  }
  return keys;
}

/**
 * Units in `only` that have neither a cache record nor an assembled shard entry.
 * `done` overrides that lookup, which is what the tests exercise.
 */
export function todoUnits({ only = "discover", limit = null, model = null, done = null } = {}) {
  ensureUnits();
  const skip = done ?? new Set([...cachedKeys({ model }), ...assembledKeys()]);
  const units = selectAuthorUnits(only).filter((u) => !skip.has(u.key));
  return limit ? units.slice(0, limit) : units;
}

// --- prompts -----------------------------------------------------------------

export function promptFor(key, { quran = loadQuran() } = {}) {
  ensureUnits();
  const unit = selectAuthorUnits(`keys:${key}`)[0];
  const themeIndexPath = path.join(OUT, "themes-index.json");
  const themeIndex = fs.existsSync(themeIndexPath) ? readJSON(themeIndexPath) : null;
  return {
    unit,
    system: buildSystem().map((b) => b.text).join("\n"),
    user: buildUserTurn(unit, { quran, themeIndex }),
  };
}

// --- writing -----------------------------------------------------------------

/**
 * Reduce an authored body to the fields the model owns. Accepts a body that
 * still carries assemble-stamped fields (key/surah/start/end/tier/meta) and
 * drops them, but refuses one whose own `key` contradicts the target.
 */
export function normaliseBody(body, key) {
  const problems = [];
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { body: null, problems: ["body is not a JSON object"] };
  }
  if (body.key !== undefined && body.key !== key) {
    problems.push(`body.key is ${JSON.stringify(body.key)} but the target unit is ${key}`);
  }
  const out = {};
  for (const f of MODEL_FIELDS) if (f in body) out[f] = body[f];
  for (const f of OPTIONAL_MODEL_FIELDS) if (f in body) out[f] = body[f];
  const allowed = new Set([...MODEL_FIELDS, ...OPTIONAL_MODEL_FIELDS]);
  for (const f of Object.keys(body)) {
    if (!allowed.has(f) && !STAMPED_FIELDS.has(f)) problems.push(`unknown field "${f}"`);
  }
  for (const f of MODEL_FIELDS) if (!(f in out)) problems.push(`missing field "${f}"`);
  return { body: out, problems };
}

/** The full study record a body would assemble into, for validation. */
export function studyFor(
  key,
  body,
  { units = null, model = AUTHOR_MODEL, receivedAt, simplified = null, author = null } = {},
) {
  const map = units ?? new Map(selectUnits("all").map((u) => [u.key, u]));
  return assembleStudy(
    {
      key,
      promptVersion: PROMPT_VERSION,
      model,
      body,
      receivedAt: receivedAt ?? "2026-01-01T00:00:00.000Z",
      ...(simplified ? { simplified, author: author ?? DEFAULT_AUTHOR } : {}),
    },
    map.get(key),
  );
}

/** Every already-written record, as validate-shaped records (for duplicate checks). */
export function corpusRecords({ exclude = new Set(), model = null } = {}) {
  const records = [];
  const seen = new Set();
  const push = (study, source) => {
    if (!study?.key || exclude.has(study.key) || seen.has(study.key)) return;
    seen.add(study.key);
    records.push({ key: study.key, study, source });
  };

  const shards = path.join(OUT, "study");
  if (fs.existsSync(shards)) {
    for (const f of fs.readdirSync(shards)) {
      if (!/^surah_\d{3}\.json$/.test(f)) continue;
      for (const s of readJSON(path.join(shards, f)).studies ?? []) push(s, f);
    }
  }
  const cache = cacheDir();
  if (fs.existsSync(cache)) {
    const units = new Map(selectUnits("all").map((u) => [u.key, u]));
    for (const f of fs.readdirSync(cache)) {
      if (!f.endsWith(".json")) continue;
      const rec = readJSON(path.join(cache, f));
      if (!rec?.key || !rec.body) continue;
      if (model && rec.model !== model) continue;
      push(
        studyFor(rec.key, rec.body, {
          units,
          model: rec.model,
          receivedAt: rec.receivedAt,
          simplified: rec.simplified ?? null,
          author: rec.author ?? null,
        }),
        f,
      );
    }
  }
  return records;
}

/**
 * Run the whole validate.mjs rule set over one or more authored bodies.
 *
 * Candidates are validated first and against the existing corpus, so the
 * near-duplicate check sees the rest of the collection; findings that belong to
 * corpus records rather than to a candidate are dropped.
 *
 * @param entries {{key: string, body: object}[]}
 * @returns Map<key, { errors: string[], warnings: string[] }>
 */
export function validateBodies(
  entries,
  { withCorpus = true, model = AUTHOR_MODEL, simplified = null, author = null } = {},
) {
  ensureUnits();
  const quran = loadQuran();
  const passages = loadPassages();
  const themes = readJSON(path.join(OUT, "themes.json")).themes;
  const themeIds = new Set(themes.map((t) => t.id));
  const themeTitles = new Map(themes.map((t) => [t.id, t.title]));
  const units = new Map(selectUnits("all").map((u) => [u.key, u]));

  const results = new Map();
  const candidates = [];
  for (const { key, body } of entries) {
    const { body: clean, problems } = normaliseBody(body, key);
    results.set(key, { errors: [...problems.map((p) => `${key}: ${p}`)], warnings: [] });
    if (!clean) continue;
    candidates.push({
      key,
      study: studyFor(key, clean, { units, model, simplified, author }),
      source: `${key}.json`,
    });
  }
  if (!candidates.length) return results;

  const keys = new Set(candidates.map((c) => c.key));
  const records = withCorpus ? [...candidates, ...corpusRecords({ exclude: keys, model })] : candidates;
  const { errors, warnings } = validateRecords(records, { quran, themeIds, themeTitles, passages });

  const sort = (list, bucket) => {
    for (const msg of list) {
      for (const key of keys) {
        if (msg.startsWith(`${key}: `)) {
          results.get(key)[bucket].push(msg);
          break;
        }
      }
    }
  };
  sort(errors, "errors");
  sort(warnings, "warnings");
  return results;
}

/**
 * Write one cache record in exactly poll-batch's shape.
 *
 * `simplified` is the extra field the rewrite pass sets; assemble.mjs turns it
 * into `meta.simplified` / `meta.author` on the shard, and that is what makes
 * validate.mjs hold the unit to the readability targets as errors.
 */
export function writeRecord(
  key,
  body,
  { author = DEFAULT_AUTHOR, model = AUTHOR_MODEL, receivedAt, simplified = null } = {},
) {
  fs.mkdirSync(cacheDir(), { recursive: true });
  const file = cachePath(model, key);
  const record = {
    key,
    promptVersion: PROMPT_VERSION,
    model,
    usage: null,
    author,
    ...(simplified ? { simplified } : {}),
    body,
    receivedAt: receivedAt ?? new Date().toISOString(),
  };
  fs.writeFileSync(file, JSON.stringify(record, null, 2) + "\n");
  return { file, record };
}

// --- status ------------------------------------------------------------------

export function statusReport({ model = null } = {}) {
  ensureUnits();
  const all = selectUnits("all");
  const cached = cachedKeys({ model });
  const assembled = assembledKeys();
  const discover = discoverKeys();
  const discoverDone = discover.filter((k) => assembled.has(k));
  const discoverCached = discover.filter((k) => cached.has(k) && !assembled.has(k));

  const bySurah = new Map();
  for (const u of all) {
    const row = bySurah.get(u.surah) ?? { surah: u.surah, units: 0, cached: 0, assembled: 0, discover: 0 };
    row.units++;
    if (cached.has(u.key)) row.cached++;
    if (assembled.has(u.key)) row.assembled++;
    if (u.tier === "discover") row.discover++;
    bySurah.set(u.surah, row);
  }

  return {
    units: all.length,
    cached: cached.size,
    assembled: assembled.size,
    discover: discover.length,
    discoverAssembled: discoverDone.length,
    discoverCachedOnly: discoverCached.length,
    discoverRemaining: discover.filter((k) => !cached.has(k) && !assembled.has(k)),
    surahs: [...bySurah.values()].filter((r) => r.cached || r.assembled).sort((a, b) => a.surah - b.surah),
  };
}

// --- the simplify pass -------------------------------------------------------
//
// A rewrite is an ordinary authored body with one extra marker. `rewriteTodoUnits`
// finds units that already exist and have not been through the pass;
// `rewritePromptFor` hands the agent prompts/simplify.md, the passage, the
// current measurements and the current body; `writeRecord(..., { simplified })`
// stamps the record so assemble.mjs writes `meta.simplified` and validate.mjs
// switches the readability rule from warning to error.

/** One cache record for `key`, or null. */
export function cacheRecordFor(key, { model = null, promptVersion = PROMPT_VERSION } = {}) {
  const dir = cacheDir();
  if (!fs.existsSync(dir)) return null;
  for (const f of fs.readdirSync(dir).sort()) {
    if (!f.endsWith(".json")) continue;
    const rec = readJSON(path.join(dir, f));
    if (rec?.key !== key || !rec.body) continue;
    if (model && rec.model !== model) continue;
    if (promptVersion && rec.promptVersion !== promptVersion) continue;
    return { ...rec, source: path.join("work", "cache", f) };
  }
  return null;
}

/**
 * The unit as it stands today, as an assembled study: a `work/cache` record wins
 * over the committed shard, because that is what the next `assemble` will ship.
 */
export function currentStudy(key, { model = null } = {}) {
  const p = parseKey(key);
  if (!p) throw new Error(`${key} is not a passage key`);
  const rec = cacheRecordFor(key, { model });
  if (rec) {
    return {
      study: studyFor(key, rec.body, {
        model: rec.model,
        receivedAt: rec.receivedAt,
        simplified: rec.simplified ?? null,
        author: rec.author ?? null,
      }),
      source: rec.source,
    };
  }
  const file = path.join(OUT, "study", `surah_${String(p.surah).padStart(3, "0")}.json`);
  if (!fs.existsSync(file)) return null;
  const study = (readJSON(file).studies ?? []).find((s) => s.key === key);
  return study ? { study, source: path.join("out", "study", path.basename(file)) } : null;
}

/** Keys already through the simplify pass, in the shards or waiting in the cache. */
export function simplifiedKeys({ model = null } = {}) {
  const keys = new Set();
  const shards = path.join(OUT, "study");
  if (fs.existsSync(shards)) {
    for (const f of fs.readdirSync(shards)) {
      if (!/^surah_\d{3}\.json$/.test(f)) continue;
      for (const s of readJSON(path.join(shards, f)).studies ?? []) {
        if (s.meta?.simplified) keys.add(s.key);
      }
    }
  }
  const dir = cacheDir();
  if (fs.existsSync(dir)) {
    for (const f of fs.readdirSync(dir)) {
      if (!f.endsWith(".json")) continue;
      const rec = readJSON(path.join(dir, f));
      if (!rec?.key || !rec.simplified) continue;
      if (model && rec.model !== model) continue;
      keys.add(rec.key);
    }
  }
  return keys;
}

/**
 * Every prose section of a study measured against the schema's grade ceilings.
 *
 * @returns {{
 *   sections: {field: string, grade: number, wordsPerSentence: number, ceiling: number, over: boolean}[],
 *   over: string[], worst: number, hasExplainEasier: boolean,
 * }}
 */
export function measureStudy(study) {
  const limit = READABILITY_TARGETS.meanSentenceWords;
  const sections = [];
  for (const [field, ceiling] of Object.entries(READABILITY_TARGETS.sections)) {
    const text = study?.[field];
    if (typeof text !== "string" || !text.trim()) continue;
    const r = readability(text);
    sections.push({
      field,
      grade: r.grade,
      wordsPerSentence: r.wordsPerSentence,
      words: r.words,
      ceiling,
      over: r.grade > ceiling || r.wordsPerSentence > limit,
    });
  }
  const explain = typeof study?.explainEasier === "string" && study.explainEasier.trim() !== "";
  if (explain) {
    const r = readability(study.explainEasier);
    sections.push({
      field: "explainEasier",
      grade: r.grade,
      wordsPerSentence: r.wordsPerSentence,
      words: r.words,
      ceiling: READABILITY_TARGETS.explainEasierGrade,
      over: r.grade > READABILITY_TARGETS.explainEasierGrade || r.wordsPerSentence > limit,
    });
  }
  return {
    sections,
    over: sections.filter((s) => s.over).map((s) => s.field),
    worst: sections.reduce((m, s) => Math.max(m, s.grade), 0),
    hasExplainEasier: explain,
  };
}

/**
 * Units in `only` that exist today and have not been simplified, worst grade first
 * in the report but in unit order here so waves can be sliced deterministically.
 */
export function rewriteTodoUnits({ only = "discover", limit = null, model = null, done = null } = {}) {
  ensureUnits();
  const byKey = new Map(corpusRecords({ model }).map((r) => [r.key, r.study]));
  const skip = done ?? simplifiedKeys({ model });
  const out = [];
  for (const u of selectAuthorUnits(only)) {
    if (skip.has(u.key)) continue;
    const study = byKey.get(u.key);
    if (!study) continue; // nothing written yet: that is `todo`, not `rewrite-todo`
    const m = measureStudy(study);
    out.push({
      key: u.key,
      surah: u.surah,
      tier: u.tier ?? "standard",
      worstGrade: m.worst,
      over: m.over,
      hasExplainEasier: m.hasExplainEasier,
      sections: m.sections,
    });
  }
  return limit ? out.slice(0, limit) : out;
}

/** The model-owned fields of a study, i.e. the shape a rewrite must write back. */
export function bodyOf(study) {
  const out = {};
  for (const f of [...MODEL_FIELDS, ...OPTIONAL_MODEL_FIELDS]) if (f in study) out[f] = study[f];
  return out;
}

/**
 * The whole rewrite turn for one unit: prompts/simplify.md, the passage in
 * English, what the sections measure today, and the current body to rewrite.
 */
export function rewritePromptFor(key, { quran = loadQuran(), model = null } = {}) {
  ensureUnits();
  const unit = selectAuthorUnits(`keys:${key}`)[0];
  const current = currentStudy(key, { model });
  if (!current) {
    throw new Error(`${key} has no study yet — it is a job for \`author.mjs prompt\`, not \`rewrite\``);
  }
  const { study, source } = current;
  const rules = fs.readFileSync(path.join(ROOT, "prompts", "simplify.md"), "utf8").trimEnd();
  const surah = quran.byNumber.get(unit.surah);

  const english = [];
  for (let a = unit.start; a <= unit.end; a++) english.push(`${a}. ${quran.english(unit.surah, a)}`);

  const m = measureStudy(study);
  const rows = m.sections.map(
    (s) =>
      `  ${s.field.padEnd(24)} grade ${String(s.grade).padStart(5)}  ` +
      `(ceiling ${s.ceiling})  ${String(s.wordsPerSentence).padStart(5)} words/sentence  ` +
      `${String(s.words).padStart(3)} words${s.over ? "   <- over" : ""}`,
  );

  const turn = [
    rules,
    "",
    "# This unit",
    "",
    `key: ${key}   surah ${surah.number} ${surah.name} (${surah.meaning})   tier: ${unit.tier ?? "standard"}`,
    `current body read from: ${source}`,
    "",
    "## The passage (English, the translation the app ships)",
    "",
    english.join("\n"),
    "",
    "## What it measures today",
    "",
    rows.join("\n"),
    m.hasExplainEasier ? "" : "  explainEasier            absent — write it",
    "",
    "## The body to rewrite",
    "",
    "```json",
    JSON.stringify(bodyOf(study), null, 2),
    "```",
    "",
  ];
  return { unit, study, source, measurements: m, text: turn.filter((l) => l !== null).join("\n") };
}

/**
 * What a rewrite is not allowed to have changed, compared with the unit as it
 * stands today. The readability and content rules are validate.mjs's job; this
 * is the diff against the previous version, which validate.mjs cannot see.
 *
 * @returns {{ errors: string[], warnings: string[] }}
 */
export function checkRewriteFidelity(key, body, { model = null } = {}) {
  const errors = [];
  const warnings = [];
  const current = currentStudy(key, { model });
  if (!current) return { errors: [`${key}: no existing unit to rewrite`], warnings };
  const was = current.study;

  if (body.key !== undefined && body.key !== key) errors.push(`${key}: body.key is ${body.key}`);
  if (body.tier !== undefined && body.tier !== was.tier) {
    errors.push(`${key}: tier is stamped from the unit list and may not be rewritten (${was.tier})`);
  }
  for (const f of ["theme", "themeId"]) {
    if (body[f] !== was[f]) {
      errors.push(`${key}: ${f} changed from ${JSON.stringify(was[f])} to ${JSON.stringify(body[f])}`);
    }
  }

  const arabicOf = (list) => (Array.isArray(list) ? list : []).map((t) => t?.arabic ?? "");
  const before = arabicOf(was.keyTerms);
  const after = arabicOf(body.keyTerms);
  if (before.join(" ") !== after.join(" ")) {
    errors.push(
      `${key}: keyTerms[].arabic must stay verbatim (was ${before.length} term(s): ` +
        `${before.join(" / ")}; now ${after.join(" / ")})`,
    );
  }

  const refsOf = (list) => (Array.isArray(list) ? list : []).map((c) => c?.ref ?? "");
  if (refsOf(was.crossReferences).join(",") !== refsOf(body.crossReferences).join(",")) {
    warnings.push(`${key}: crossReferences point somewhere else than they did`);
  }
  const asList = (l) => (Array.isArray(l) ? l : []).join(",");
  if (asList(was.exploreFurther) !== asList(body.exploreFurther)) {
    warnings.push(`${key}: exploreFurther points somewhere else than it did`);
  }
  if (body.title !== was.title) warnings.push(`${key}: title changed to ${JSON.stringify(body.title)}`);
  return { errors, warnings };
}
