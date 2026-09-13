#!/usr/bin/env node
// Validates generated study records.
//
//   node validate.mjs out/study      # assembled shards (the DoD gate)
//   node validate.mjs work/cache     # raw batch results, before assembly
//   node validate.mjs reflections    # Content/reflections.json (the Discover quote cards)
//
// Exits 0 only when every record passes every rule. Warnings do not fail.
import fs from "node:fs";
import path from "node:path";
import Ajv from "ajv";
import { ROOT, OUT, loadQuran, hasArabic, parseKey, refInBounds, words } from "./lib/data.mjs";
import { loadPassages } from "./lib/units.mjs";
import { nfc, looseArabic, unitUthmani, exactSpanFor } from "./lib/arabic.mjs";

const SCHEMA = JSON.parse(fs.readFileSync(path.join(ROOT, "schema", "study.schema.json"), "utf8"));
const PROSE_FIELDS = [
  "title", "theme", "meaning", "historicalContext", "lifeInProphetsTime",
  "didYouKnow", "theologicalSignificance", "applyIt",
];

// Legal-ruling and sectarian language the content rules forbid, plus LLM tells.
const BANNED = [
  [/\bfatw[aā]\b/i, "legal ruling language"],
  [/\bit is (obligatory|forbidden|impermissible|permissible|prohibited)\b/i, "legal ruling language"],
  [/\byou must\b/i, "prescriptive ruling"],
  [/\b(har[aā]m|hal[aā]l)\b/i, "legal ruling language"],
  [/\b(sunni|shia|shi'a|shi‘a|wahhabi|salafi|sufi|ash'ari|mu'tazil)/i, "sectarian framing"],
  [/\b(hanafi|shafi'?i|maliki|hanbali|madhhab|madhab)\b/i, "school-of-law framing"],
  [/\bas an ai\b/i, "model self-reference"],
  [/\bthis (verse|passage) reminds us\b/i, "filler opener"],
  [/\bin conclusion\b/i, "filler"],
  [/\bAllah\b/, "use \"God\" in English prose"],
];

/** Sections compared for near-duplication across the whole corpus. */
const DUP_FIELDS = ["meaning", "didYouKnow", "applyIt"];
const DUP_ERROR = 0.5;
const DUP_WARN = 0.35;

/**
 * Prose scripts a note may legitimately contain. Latin covers the English and
 * the transliterated names in the tafsir tradition (al-Sa'di, al-Tabari);
 * Common and Inherited cover punctuation, digits and combining accents. Arabic
 * is deliberately absent: `hasArabic` reports it with a more specific message.
 * Anything else — a stray Cyrillic or Greek word — is a copy-paste accident.
 */
const FOREIGN_SCRIPT = /[^\p{Script=Latin}\p{Script=Common}\p{Script=Inherited}\p{Script=Arabic}]/gu;

const shingles = (text, n = 5) => {
  const w = text.toLowerCase().replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter(Boolean);
  const out = new Set();
  for (let i = 0; i + n <= w.length; i++) out.add(w.slice(i, i + n).join(" "));
  return out;
};

/** The distinct characters of `text` in a script a note may not contain, or null. */
const foreignScript = (text) => {
  const hits = String(text ?? "").match(FOREIGN_SCRIPT);
  if (!hits) return null;
  return [...new Set(hits)]
    .map((c) => `${JSON.stringify(c)} (U+${c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")})`)
    .join(", ");
};

const jaccard = (a, b) => {
  if (!a.size || !b.size) return 0;
  let inter = 0;
  for (const x of a) if (b.has(x)) inter++;
  return inter / (a.size + b.size - inter);
};

/** Reads a directory of shards or cache files into { key, study, source }[]. */
export function loadRecords(dir) {
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json") && f !== "passages.json")
    .sort();
  const records = [];
  for (const f of files) {
    const full = path.join(dir, f);
    const raw = JSON.parse(fs.readFileSync(full, "utf8"));
    if (raw.body && raw.key) {
      records.push({ key: raw.key, study: { ...raw.body, key: raw.key }, source: f, partial: true });
    } else if (Array.isArray(raw)) {
      for (const s of raw) records.push({ key: s.key, study: s, source: f });
    } else if (raw.studies) {
      for (const s of raw.studies) records.push({ key: s.key, study: s, source: f });
    } else {
      records.push({ key: raw.key, study: raw, source: f });
    }
  }
  return records;
}

export function validateRecords(records, { quran, themeIds, themeTitles = null, passages }) {
  const ajv = new Ajv({ allErrors: true, strict: false });
  ajv.addFormat("date-time", (v) => !Number.isNaN(Date.parse(v)));
  const full = ajv.compile(SCHEMA);
  const bounds = SCHEMA["x-wordBounds"];
  const errors = [];
  const warnings = [];
  const unitKeys = new Set(Object.values(passages));

  const err = (key, msg) => errors.push(`${key}: ${msg}`);
  const warn = (key, msg) => warnings.push(`${key}: ${msg}`);

  const checkWords = (key, field, text) => {
    const b = bounds[field];
    if (!b) return;
    const n = words(text);
    if (n < b[0] || n > b[1]) err(key, `${field} is ${n} words, must be ${b[0]}-${b[1]}`);
  };

  for (const rec of records) {
    const s = rec.study;
    const key = rec.key ?? "<no key>";

    if (!rec.partial && !full(s)) {
      for (const e of full.errors.slice(0, 6)) err(key, `schema ${e.instancePath || "/"} ${e.message}`);
    }

    const parsed = parseKey(s.key ?? key);
    if (!parsed) {
      err(key, "unparseable key");
      continue;
    }
    if (!unitKeys.has(s.key ?? key)) err(key, "key is not a unit key in out/study/passages.json");
    if (!rec.partial) {
      if (s.surah !== parsed.surah || s.start !== parsed.start || s.end !== parsed.end) {
        err(key, "surah/start/end disagree with key");
      }
    }

    // Prose fields: word bounds, no Arabic script, no banned phrasing.
    for (const f of PROSE_FIELDS) {
      const text = s[f];
      if (typeof text !== "string") {
        err(key, `${f} missing`);
        continue;
      }
      checkWords(key, f, text);
      if (hasArabic(text)) err(key, `${f} contains Arabic script (only keyTerms[].arabic may)`);
      const foreign = foreignScript(text);
      if (foreign) err(key, `${f} contains non-Latin script: ${foreign}`);
      for (const [re, why] of BANNED) if (re.test(text)) err(key, `${f}: ${why} (${re})`);
    }
    if (typeof s.title === "string" && /[.!?]$/.test(s.title.trim())) {
      err(key, "title has trailing punctuation");
    }

    // Nested prose (key-term glosses/notes, cross-reference reasons): banned phrasing applies there too.
    const nested = [];
    if (Array.isArray(s.keyTerms)) for (const [i, t] of s.keyTerms.entries()) {
      for (const f of ["gloss", "note"]) if (typeof t?.[f] === "string") nested.push([`keyTerms[${i}].${f}`, t[f]]);
    }
    if (Array.isArray(s.crossReferences)) for (const [i, c] of s.crossReferences.entries()) {
      if (typeof c?.why === "string") nested.push([`crossReferences[${i}].why`, c.why]);
    }
    for (const [f, text] of nested) {
      const foreign = foreignScript(text);
      if (foreign) err(key, `${f} contains non-Latin script: ${foreign}`);
      for (const [re, why] of BANNED) if (re.test(text)) err(key, `${f}: ${why} (${re})`);
    }

    // Honorific: if the Prophet Muhammad is named, the first naming carries it.
    const prose = [...PROSE_FIELDS.map((f) => s[f]), ...nested.map(([, t]) => t)]
      .filter((t) => typeof t === "string").join(" ");
    if (/\bMuhammad\b/.test(prose) && !/Muhammad \(peace be upon him\)/.test(prose)) {
      err(key, 'names Muhammad without the honorific "(peace be upon him)"');
    }
    if ((prose.match(/\(peace be upon him\)/g) ?? []).length > 1) {
      warn(key, "honorific used more than once");
    }

    // Key terms.
    if (Array.isArray(s.keyTerms)) {
      // The unit's own Uthmani text, Bismillah stripped: every key term has to
      // come out of it, character for character.
      const surahMeta = quran.byNumber.get(parsed.surah);
      const passage =
        surahMeta && parsed.start >= 1 && parsed.end <= surahMeta.ayahCount
          ? unitUthmani(quran, parsed)
          : null;
      const passageLoose = passage === null ? null : looseArabic(passage);

      for (const [i, t] of s.keyTerms.entries()) {
        if (!hasArabic(t.arabic ?? "")) err(key, `keyTerms[${i}].arabic is not Arabic script`);
        if (/[A-Za-z]/.test(t.arabic ?? "")) err(key, `keyTerms[${i}].arabic contains Latin letters`);
        if (passage !== null && hasArabic(t.arabic ?? "")) {
          const term = nfc(t.arabic);
          if (!passage.includes(term)) {
            // Diacritics-insensitive second pass: it separates "this word is not
            // in the passage" from "this word is in the passage but was retyped"
            // (a dropped tatweel carrier, a plain alef for a dagger alef, a
            // missing Quranic annotation sign).
            if (passageLoose.includes(looseArabic(term))) {
              err(
                key,
                `keyTerms[${i}].arabic is not copied verbatim from ${key}: ` +
                  `${term} — the text has ${exactSpanFor(passage, term)}`,
              );
            } else {
              err(key, `keyTerms[${i}].arabic does not occur in ${key}: ${term}`);
            }
          }
        }
        for (const f of ["gloss", "note"]) {
          if (hasArabic(t[f] ?? "")) err(key, `keyTerms[${i}].${f} contains Arabic script`);
          checkWords(key, `keyTerms[].${f}`, t[f] ?? "");
        }
      }
    }

    // References.
    const refs = [
      ...(s.crossReferences ?? []).map((c, i) => [c.ref, `crossReferences[${i}].ref`]),
      ...(s.exploreFurther ?? []).map((r, i) => [r, `exploreFurther[${i}]`]),
    ];
    for (const [ref, where] of refs) {
      if (!refInBounds(ref, quran.byNumber)) err(key, `${where} out of bounds: ${ref}`);
      const rp = parseKey(ref);
      // "Read this next" must lead somewhere else: any overlap with the unit's
      // own ayat sends the reader back to the page they are already on.
      if (rp && rp.surah === parsed.surah && rp.start <= parsed.end && rp.end >= parsed.start) {
        err(
          key,
          ref === s.key
            ? `${where} points at the passage itself: ${ref}`
            : `${where} overlaps the passage's own ayat: ${ref}`,
        );
      }
    }
    for (const [i, c] of (s.crossReferences ?? []).entries()) {
      checkWords(key, "crossReferences[].why", c.why ?? "");
      if (hasArabic(c.why ?? "")) err(key, `crossReferences[${i}].why contains Arabic script`);
    }

    if (s.themeId && !themeIds.has(s.themeId)) err(key, `unknown themeId "${s.themeId}"`);
    // The pill in the app is rendered from `theme`; the Swift ThemeIndex joins on
    // `themeId`. They drift silently unless the title is checked verbatim.
    if (s.themeId && themeTitles?.has(s.themeId) && s.theme !== themeTitles.get(s.themeId)) {
      err(
        key,
        `theme "${s.theme}" is not the title of themeId "${s.themeId}" ` +
          `(themes.json says "${themeTitles.get(s.themeId)}")`,
      );
    }
  }

  // Near-duplicate detection. `meaning` says what the passage means and two
  // similar passages can legitimately come close; `didYouKnow` and `applyIt` are
  // supposed to be unique per note, and a fact or an exercise reused across
  // units is the failure readers notice fastest.
  for (const field of DUP_FIELDS) {
    const sig = records
      .filter((r) => typeof r.study[field] === "string")
      .map((r) => ({ key: r.key, sh: shingles(r.study[field]) }));

    // Only records sharing at least one 5-word shingle can clear the threshold,
    // so an inverted index replaces the full n^2 sweep.
    const byShingle = new Map();
    for (const [i, s] of sig.entries()) {
      for (const g of s.sh) {
        const bucket = byShingle.get(g);
        if (bucket) bucket.push(i);
        else byShingle.set(g, [i]);
      }
    }
    const pairs = new Set();
    for (const bucket of byShingle.values()) {
      if (bucket.length < 2 || bucket.length > 400) continue;
      for (let a = 0; a < bucket.length; a++) {
        for (let b = a + 1; b < bucket.length; b++) pairs.add(bucket[a] * sig.length + bucket[b]);
      }
    }
    for (const packed of pairs) {
      const i = Math.floor(packed / sig.length);
      const j = packed % sig.length;
      const score = jaccard(sig[i].sh, sig[j].sh);
      if (score >= DUP_ERROR) {
        err(sig[i].key, `${field} is a near-duplicate of ${sig[j].key} (${score.toFixed(2)})`);
      } else if (score >= DUP_WARN) {
        warn(sig[i].key, `${field} overlaps ${sig[j].key} (${score.toFixed(2)})`);
      }
    }
  }

  return { errors, warnings };
}

/**
 * The `reflections` sub-command: checks the artefact, not the catalogue.
 *
 * `build-reflections.mjs` already refuses to write a file that breaks a rule, so this is the
 * gate that catches a `Content/reflections.json` edited by hand or left behind by an older
 * catalogue. It re-reads the shipped file and re-applies the countable rules from
 * `docs/content/reflections.md`: shape, word count, unique renderings, and themes that
 * resolve against `Content/themes.json`.
 */
async function validateReflections() {
  const { RULES } = await import("./build-reflections.mjs");
  const repo = path.dirname(path.dirname(ROOT));
  const file = path.join(repo, "Content", "reflections.json");
  if (!fs.existsSync(file)) {
    console.error(`no such file: ${file} — run node Tools/content-gen/build-reflections.mjs`);
    process.exit(1);
  }
  const themeIds = new Set(
    JSON.parse(fs.readFileSync(path.join(repo, "Content", "themes.json"), "utf8")).themes.map((t) => t.id),
  );
  const data = JSON.parse(fs.readFileSync(file, "utf8"));
  const errors = [];
  const err = (id, msg) => errors.push(`${id}: ${msg}`);

  if (data.version !== RULES.version) errors.push(`file: version is ${data.version}, expected ${RULES.version}`);
  if (data.generatedAt !== RULES.generatedAt) {
    errors.push(`file: generatedAt is not the fixed string the build writes`);
  }
  if (!Array.isArray(data.items)) {
    console.error("reflections.json has no items array");
    process.exit(1);
  }
  if (data.count !== data.items.length) errors.push(`file: count ${data.count} but ${data.items.length} items`);
  if (data.items.length < RULES.minShipped) {
    errors.push(`file: ${data.items.length} items, at least ${RULES.minShipped} are needed`);
  }

  const ids = new Set();
  const texts = new Map();
  const byTheme = new Map([...themeIds].map((id) => [id, 0]));
  for (const item of data.items) {
    const id = item.id ?? "<no id>";
    if (ids.has(id)) err(id, "duplicate id");
    ids.add(id);
    if (item.confidence !== "high") err(id, `confidence is "${item.confidence}"; only high ships`);
    if (!item.attribution?.trim()) err(id, "no attribution");
    if (!item.source?.work?.trim()) err(id, "no source work");
    if (!item.source?.locator?.trim()) err(id, "no source locator");
    if (item.source?.translator !== "own") err(id, "every rendering is the app's own");
    const n = words(item.text ?? "");
    if (n < RULES.words[0] || n > RULES.words[1]) {
      err(id, `text is ${n} words, must be ${RULES.words[0]}-${RULES.words[1]}`);
    }
    if (hasArabic(item.text ?? "")) err(id, "text carries Arabic script");
    if (item.arabic !== undefined && !hasArabic(item.arabic)) err(id, '"arabic" is not Arabic script');
    const key = String(item.text).toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
    if (texts.has(key)) err(id, `same rendering as ${texts.get(key)}`);
    else texts.set(key, id);
    if (!Array.isArray(item.themes) || item.themes.length === 0) err(id, "no themes");
    for (const theme of item.themes ?? []) {
      if (!themeIds.has(theme)) err(id, `unknown theme "${theme}"`);
      else byTheme.set(theme, byTheme.get(theme) + 1);
    }
  }
  for (const [theme, n] of byTheme) {
    if (n < RULES.minPerTheme) errors.push(`theme "${theme}": ${n} entries, at least ${RULES.minPerTheme}`);
  }

  console.log(`validated ${data.items.length} reflection(s) in Content/reflections.json`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`\n${errors.length} error(s), 0 warning(s)`);
  if (errors.length) process.exit(1);
  console.log("OK");
}

function main(argv = process.argv.slice(2)) {
  if (argv[0] === "reflections") return validateReflections();
  const dir = argv.find((a) => !a.startsWith("--")) ?? path.join(OUT, "study");
  if (!fs.existsSync(dir)) {
    console.error(`no such directory: ${dir}`);
    process.exit(1);
  }
  const records = loadRecords(dir);
  const quran = loadQuran();
  const themes = JSON.parse(fs.readFileSync(path.join(OUT, "themes.json"), "utf8")).themes;
  const themeIds = new Set(themes.map((t) => t.id));
  const themeTitles = new Map(themes.map((t) => [t.id, t.title]));
  const passages = loadPassages();

  if (!records.length) {
    console.log(`${dir}: 0 study records found — nothing to validate.`);
    console.log("OK (vacuous): run the pipeline first if you expected content here.");
    return;
  }

  const { errors, warnings } = validateRecords(records, { quran, themeIds, themeTitles, passages });

  console.log(`validated ${records.length} record(s) in ${dir}`);
  for (const w of warnings) console.log(`WARN  ${w}`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`\n${errors.length} error(s), ${warnings.length} warning(s)`);
  if (errors.length) process.exit(1);
  console.log("OK");
}

if (import.meta.url === `file://${process.argv[1]}`) main();
export { main };
