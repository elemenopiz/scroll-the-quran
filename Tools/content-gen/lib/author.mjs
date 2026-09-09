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

export const AUTHOR_MODEL = "claude-opus-5";
export const DEFAULT_AUTHOR = "opus-session";

const SCHEMA = JSON.parse(fs.readFileSync(path.join(ROOT, "schema", "study.schema.json"), "utf8"));
/** The fields an author actually writes; everything else is stamped by assemble. */
export const MODEL_FIELDS = SCHEMA["x-modelFields"];
const STAMPED_FIELDS = new Set(["key", "surah", "start", "end", "tier", "meta"]);

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
  for (const f of Object.keys(body)) {
    if (!MODEL_FIELDS.includes(f) && !STAMPED_FIELDS.has(f)) problems.push(`unknown field "${f}"`);
  }
  for (const f of MODEL_FIELDS) if (!(f in out)) problems.push(`missing field "${f}"`);
  return { body: out, problems };
}

/** The full study record a body would assemble into, for validation. */
export function studyFor(key, body, { units = null, model = AUTHOR_MODEL, receivedAt } = {}) {
  const map = units ?? new Map(selectUnits("all").map((u) => [u.key, u]));
  return assembleStudy(
    {
      key,
      promptVersion: PROMPT_VERSION,
      model,
      body,
      receivedAt: receivedAt ?? "2026-01-01T00:00:00.000Z",
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
      push(studyFor(rec.key, rec.body, { units, model: rec.model, receivedAt: rec.receivedAt }), f);
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
export function validateBodies(entries, { withCorpus = true, model = AUTHOR_MODEL } = {}) {
  ensureUnits();
  const quran = loadQuran();
  const passages = loadPassages();
  const themeIds = new Set(readJSON(path.join(OUT, "themes.json")).themes.map((t) => t.id));
  const units = new Map(selectUnits("all").map((u) => [u.key, u]));

  const results = new Map();
  const candidates = [];
  for (const { key, body } of entries) {
    const { body: clean, problems } = normaliseBody(body, key);
    results.set(key, { errors: [...problems.map((p) => `${key}: ${p}`)], warnings: [] });
    if (!clean) continue;
    candidates.push({ key, study: studyFor(key, clean, { units, model }), source: `${key}.json` });
  }
  if (!candidates.length) return results;

  const keys = new Set(candidates.map((c) => c.key));
  const records = withCorpus ? [...candidates, ...corpusRecords({ exclude: keys, model })] : candidates;
  const { errors, warnings } = validateRecords(records, { quran, themeIds, passages });

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

/** Write one cache record in exactly poll-batch's shape. */
export function writeRecord(key, body, { author = DEFAULT_AUTHOR, model = AUTHOR_MODEL, receivedAt } = {}) {
  fs.mkdirSync(cacheDir(), { recursive: true });
  const file = cachePath(model, key);
  const record = {
    key,
    promptVersion: PROMPT_VERSION,
    model,
    usage: null,
    author,
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
