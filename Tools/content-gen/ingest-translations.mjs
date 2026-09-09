#!/usr/bin/env node
// Scroll the Quran - Quran text / translation / metadata ingest.
//
//   node Tools/content-gen/ingest-translations.mjs --fetch    download + build out/quran/*.json
//   node Tools/content-gen/ingest-translations.mjs --verify   re-validate everything from disk
//
// Options:
//   --only=arabic,itani,saheeh,ruwwad,pickthall,surahs   restrict what --fetch rebuilds
//   --refetch                                            ignore the work/raw HTTP cache
//
// Node 24 built-ins only. Raw HTTP responses are cached under work/raw (gitignored);
// the committed artefacts are Tools/content-gen/out/quran/*.json.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  TOTAL_AYAHS,
  TOTAL_SURAHS,
  TOTAL_JUZ,
  TOTAL_PAGES,
  CANONICAL_AYAH_COUNTS,
  hasArabic,
  arabicChars,
  flattenCanonical,
} from "./lib/quran.mjs";
import {
  parseTanzilText,
  extractTanzilCopyright,
  parseFawazEdition,
  parseQuranEncSura,
  parseQuranMetadata,
  buildSurahs,
} from "./lib/parsers.mjs";
import { fetchText, fetchJson, sleep } from "./lib/fetch-util.mjs";
import { buildRegistry, REGISTRY_FIELDS, REQUIRED_STRINGS } from "./lib/registry.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, "out", "quran");
const RAW = path.join(HERE, "work", "raw");
const FONTS = path.join(HERE, "out", "fonts");

const QURANENC_DELAY_MS = 150;

const SOURCES = {
  tanzilText:
    "https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=txt-2&marks=true&sajdah=true&alef=true&tatweel=true&agree=true",
  tanzilMetadata: "https://tanzil.net/res/text/metadata/quran-data.xml",
  fawazArabic:
    "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranuthmanihaf.json",
  fawazItani: "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-talalitani.json",
  fawazPickthall:
    "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-mohammedmarmadu.json",
  quranEncList: "https://quranenc.com/api/v1/translations/list",
  quranEncSura: (key, n) => `https://quranenc.com/api/v1/translation/sura/${key}/${n}`,
};

/* -------------------------------------------------------------------------- */
/* CLI                                                                        */
/* -------------------------------------------------------------------------- */

function main() {
  const argv = process.argv.slice(2);
  const wantFetch = argv.includes("--fetch");
  const wantVerify = argv.includes("--verify");
  const refetch = argv.includes("--refetch");
  const onlyArg = argv.find((a) => a.startsWith("--only="));
  const only = onlyArg ? new Set(onlyArg.slice("--only=".length).split(",").filter(Boolean)) : null;

  if (!wantFetch && !wantVerify) {
    console.error(
      "usage: ingest-translations.mjs [--fetch [--only=a,b] [--refetch]] [--verify]",
    );
    process.exit(2);
  }
  return (async () => {
    if (wantFetch) await runFetch({ only, refetch });
    if (wantVerify) return runVerify();
    return 0;
  })();
}

/* -------------------------------------------------------------------------- */
/* Fetch                                                                      */
/* -------------------------------------------------------------------------- */

async function runFetch({ only, refetch }) {
  fs.mkdirSync(OUT, { recursive: true });
  fs.mkdirSync(RAW, { recursive: true });
  const want = (name) => !only || only.has(name);
  const log = [];
  const stamp = () => new Date().toISOString();

  // --- metadata / surahs.json (always needed: it drives every canonical check)
  const metaXml = await cachedText("quran-data.xml", SOURCES.tanzilMetadata, refetch);
  log.push({ artifact: "quran-data.xml", url: SOURCES.tanzilMetadata, fetchedAt: stamp() });
  const meta = parseQuranMetadata(metaXml);
  const surahs = buildSurahs(meta);
  const ayahCounts = surahs.map((s) => s.ayahCount);
  if (want("surahs")) {
    writeJson(path.join(OUT, "surahs.json"), surahs);
    console.log(`surahs.json          ${surahs.length} surahs, ${sum(ayahCounts)} ayat`);
  }

  // --- Arabic (Tanzil Uthmani, fawazahmed0 as fallback)
  if (want("arabic")) {
    let entries;
    let usedSource;
    try {
      const raw = await cachedText("tanzil-uthmani.txt", SOURCES.tanzilText, refetch);
      if (/^\s*<(!doctype|html)/i.test(raw)) throw new Error("Tanzil returned HTML, not text");
      entries = parseTanzilText(raw);
      usedSource = SOURCES.tanzilText;
      fs.writeFileSync(path.join(RAW, "tanzil-copyright.txt"), extractTanzilCopyright(raw));
    } catch (err) {
      console.warn(`  ! Tanzil download failed (${err.message}); falling back to fawazahmed0 CDN`);
      const raw = await cachedText("ara-quranuthmanihaf.json", SOURCES.fawazArabic, refetch);
      entries = parseFawazEdition(raw);
      usedSource = SOURCES.fawazArabic;
    }
    const flat = flattenCanonical(entries, ayahCounts, "arabic-uthmani");
    writeJson(path.join(OUT, "arabic-uthmani.json"), flat);
    log.push({ artifact: "arabic-uthmani.json", url: usedSource, fetchedAt: stamp() });
    console.log(`arabic-uthmani.json  ${flat.length} ayat from ${usedSource}`);
  }

  // --- fawazahmed0 translations
  for (const [name, url] of [
    ["itani", SOURCES.fawazItani],
    ["pickthall", SOURCES.fawazPickthall],
  ]) {
    if (!want(name)) continue;
    const raw = await cachedText(`${name}.source.json`, url, refetch);
    const entries = parseFawazEdition(raw);
    const flat = flattenCanonical(entries, ayahCounts, name);
    writeJson(path.join(OUT, `${name}.json`), flat);
    log.push({ artifact: `${name}.json`, url, fetchedAt: stamp() });
    console.log(`${name.padEnd(20)} ${flat.length} ayat from ${url}`);
  }

  // --- QuranEnc translations (sequential, delayed, retried)
  const encVersions = {};
  if (want("saheeh") || want("ruwwad")) {
    const list = await cachedJson("quranenc-list.json", SOURCES.quranEncList, refetch);
    for (const t of list.translations ?? []) {
      if (t.key === "english_saheeh") encVersions.saheehVersion = t.version;
      if (t.key === "english_rwwad") encVersions.ruwwadVersion = t.version;
    }
    log.push({ artifact: "quranenc-list.json", url: SOURCES.quranEncList, fetchedAt: stamp() });
  }
  for (const [name, key] of [
    ["saheeh", "english_saheeh"],
    ["ruwwad", "english_rwwad"],
  ]) {
    if (!want(name)) continue;
    const entries = [];
    for (let n = 1; n <= TOTAL_SURAHS; n += 1) {
      const url = SOURCES.quranEncSura(key, n);
      const doc = await cachedJson(
        path.join(key, `${String(n).padStart(3, "0")}.json`),
        url,
        refetch,
        { delayMs: QURANENC_DELAY_MS },
      );
      const rows = parseQuranEncSura(doc);
      if (rows.length !== ayahCounts[n - 1]) {
        throw new Error(`${key}: surah ${n} returned ${rows.length} ayat, expected ${ayahCounts[n - 1]}`);
      }
      entries.push(...rows);
      if (n % 20 === 0 || n === TOTAL_SURAHS) {
        process.stdout.write(`  ${key}: ${n}/${TOTAL_SURAHS} surahs\r`);
      }
    }
    process.stdout.write("\n");
    const flat = flattenCanonical(entries, ayahCounts, name);
    writeJson(path.join(OUT, `${name}.json`), flat);
    log.push({
      artifact: `${name}.json`,
      url: SOURCES.quranEncSura(key, "{1..114}"),
      version: name === "saheeh" ? encVersions.saheehVersion : encVersions.ruwwadVersion,
      fetchedAt: stamp(),
    });
    console.log(`${name.padEnd(20)} ${flat.length} ayat from QuranEnc ${key}`);
  }

  // --- registry
  const wantRegistry =
    !only || only.has("translations") || only.has("saheeh") || only.has("ruwwad");
  if (wantRegistry) {
    const existing = readJsonIfExists(path.join(OUT, "translations.json"));
    const versions = {
      saheehVersion:
        encVersions.saheehVersion ?? versionFromCopyright(existing, "saheeh") ?? undefined,
      ruwwadVersion:
        encVersions.ruwwadVersion ?? versionFromCopyright(existing, "ruwwad") ?? undefined,
    };
    writeJson(path.join(OUT, "translations.json"), buildRegistry(versions));
    console.log(
      `translations.json    4 translations (QuranEnc versions saheeh=${versions.saheehVersion} ruwwad=${versions.ruwwadVersion})`,
    );
  }

  fs.writeFileSync(
    path.join(HERE, "work", "fetch-log.json"),
    `${JSON.stringify(log, null, 2)}\n`,
  );
  console.log(`\nfetch log: ${path.join(HERE, "work", "fetch-log.json")}`);
}

function versionFromCopyright(registry, id) {
  if (!Array.isArray(registry)) return null;
  const entry = registry.find((e) => e.id === id);
  const m = entry && /version ([\d.]+)/.exec(entry.copyright ?? "");
  return m ? m[1] : null;
}

async function cachedText(name, url, refetch, opts = {}) {
  const file = path.join(RAW, name);
  if (!refetch && fs.existsSync(file) && fs.statSync(file).size > 0) {
    return fs.readFileSync(file, "utf8");
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const body = await fetchText(url, { log: (m) => console.warn(m) });
  fs.writeFileSync(file, body);
  if (opts.delayMs) await sleep(opts.delayMs);
  return body;
}

async function cachedJson(name, url, refetch, opts = {}) {
  const file = path.join(RAW, name);
  if (!refetch && fs.existsSync(file) && fs.statSync(file).size > 0) {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const doc = await fetchJson(url, { log: (m) => console.warn(m) });
  fs.writeFileSync(file, `${JSON.stringify(doc)}\n`);
  if (opts.delayMs) await sleep(opts.delayMs);
  return doc;
}

/* -------------------------------------------------------------------------- */
/* Verify                                                                     */
/* -------------------------------------------------------------------------- */

const TRANSLATION_FILES = ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"];

function runVerify() {
  const problems = [];
  const fail = (msg) => problems.push(msg);
  // `ok` only prints when nothing failed since the mark taken by `section`.
  let mark = 0;
  const section = () => {
    mark = problems.length;
  };
  const ok = (msg) => {
    if (problems.length === mark) console.log(`  ok    ${msg}`);
  };

  console.log(`verifying ${path.relative(process.cwd(), OUT) || OUT}`);

  // ---- surahs.json
  let surahs = null;
  section();
  const surahsPath = path.join(OUT, "surahs.json");
  if (!fs.existsSync(surahsPath)) {
    fail("surahs.json is missing");
  } else {
    surahs = JSON.parse(fs.readFileSync(surahsPath, "utf8"));
    verifySurahs(surahs, fail, ok);
  }
  const ayahCounts = Array.isArray(surahs) && surahs.length === TOTAL_SURAHS
    ? surahs.map((s) => s.ayahCount)
    : CANONICAL_AYAH_COUNTS;

  // ---- arabic-uthmani.json
  section();
  const arabic = readArray(path.join(OUT, "arabic-uthmani.json"), fail);
  if (arabic) {
    verifyArray("arabic-uthmani.json", arabic, fail, ok, {
      requireArabic: true,
      surahs,
      ayahCounts,
    });
  }

  // ---- translations
  for (const file of TRANSLATION_FILES) {
    section();
    const arr = readArray(path.join(OUT, file), fail);
    if (arr) verifyArray(file, arr, fail, ok, { requireArabic: false, surahs, ayahCounts });
  }

  // ---- registry
  section();
  verifyRegistry(fail, ok);

  // ---- fonts
  section();
  verifyFonts(fail, ok);

  console.log("");
  if (problems.length > 0) {
    console.error(`FAILED: ${problems.length} problem(s)`);
    for (const p of problems) console.error(`  - ${p}`);
    return 1;
  }
  console.log(
    `PASS: ${TOTAL_SURAHS} surahs, ${TOTAL_AYAHS} ayat x ${TRANSLATION_FILES.length + 1} text files ` +
      `(1 Arabic + ${TRANSLATION_FILES.length} English), registry of ${TRANSLATION_FILES.length}.`,
  );
  return 0;
}

function readArray(file, fail) {
  if (!fs.existsSync(file)) {
    fail(`${path.basename(file)} is missing`);
    return null;
  }
  let doc;
  try {
    doc = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (err) {
    fail(`${path.basename(file)} is not valid JSON: ${err.message}`);
    return null;
  }
  if (!Array.isArray(doc)) {
    fail(`${path.basename(file)} is not a JSON array`);
    return null;
  }
  return doc;
}

function verifyArray(label, arr, fail, ok, { requireArabic, surahs, ayahCounts }) {
  if (arr.length !== TOTAL_AYAHS) {
    fail(`${label}: ${arr.length} entries, expected ${TOTAL_AYAHS}`);
    return;
  }
  let empty = 0;
  let wrongType = 0;
  let arabicViolations = [];
  let noLatin = [];
  for (let i = 0; i < arr.length; i += 1) {
    const v = arr[i];
    if (typeof v !== "string") {
      wrongType += 1;
      continue;
    }
    if (v.trim() === "") {
      empty += 1;
      continue;
    }
    const isArabic = hasArabic(v);
    if (requireArabic && !isArabic) arabicViolations.push(refOf(i, ayahCounts));
    if (!requireArabic && isArabic) {
      arabicViolations.push(`${refOf(i, ayahCounts)} (${arabicChars(v).join("")})`);
    }
    if (!requireArabic && !/[A-Za-z]/.test(v)) noLatin.push(refOf(i, ayahCounts));
  }
  if (wrongType) fail(`${label}: ${wrongType} entries are not strings`);
  if (empty) fail(`${label}: ${empty} empty entries`);
  if (arabicViolations.length) {
    fail(
      `${label}: ${arabicViolations.length} entries ${requireArabic ? "without" : "containing"} ` +
        `Arabic script (first: ${arabicViolations.slice(0, 5).join(", ")})`,
    );
  }
  if (noLatin.length) {
    fail(`${label}: ${noLatin.length} entries with no Latin letters (first: ${noLatin.slice(0, 5).join(", ")})`);
  }
  // Spot-check canonical alignment on well-known anchors.
  if (surahs) {
    const idx = (s, a) => surahs[s - 1].startIndex + a - 1;
    if (idx(2, 255) !== 261) fail(`${label}: 2:255 does not map to global index 261`);
    if (idx(114, 6) !== TOTAL_AYAHS - 1) fail(`${label}: 114:6 is not the last entry`);
  }
  ok(
    `${label.padEnd(20)} ${arr.length} entries, ` +
      `${requireArabic ? "all Arabic" : "no Arabic"}, none empty`,
  );
}

function refOf(globalIndex, ayahCounts) {
  let i = globalIndex;
  for (let s = 0; s < ayahCounts.length; s += 1) {
    if (i < ayahCounts[s]) return `${s + 1}:${i + 1}`;
    i -= ayahCounts[s];
  }
  return `#${globalIndex}`;
}

function verifySurahs(surahs, fail, ok) {
  if (!Array.isArray(surahs) || surahs.length !== TOTAL_SURAHS) {
    fail(`surahs.json: expected ${TOTAL_SURAHS} entries, got ${Array.isArray(surahs) ? surahs.length : "non-array"}`);
    return;
  }
  const fields = ["number", "name", "meaning", "ayahCount", "revelation", "startIndex", "juz", "pages"];
  let expectedStart = 0;
  const juzSeen = new Set();
  for (let i = 0; i < surahs.length; i += 1) {
    const s = surahs[i];
    const at = `surahs.json[${i}]`;
    for (const f of fields) {
      if (!Object.hasOwn(s, f)) fail(`${at}: missing field "${f}"`);
    }
    if (s.number !== i + 1) fail(`${at}: number is ${s.number}, expected ${i + 1}`);
    if (typeof s.name !== "string" || s.name.trim() === "") fail(`${at}: empty name`);
    if (typeof s.meaning !== "string" || s.meaning.trim() === "") fail(`${at}: empty meaning`);
    if (s.ayahCount !== CANONICAL_AYAH_COUNTS[i]) {
      fail(`${at}: ayahCount ${s.ayahCount}, canonical ${CANONICAL_AYAH_COUNTS[i]}`);
    }
    if (s.revelation !== "makki" && s.revelation !== "madani") {
      fail(`${at}: revelation "${s.revelation}" is not makki/madani`);
    }
    if (s.startIndex !== expectedStart) {
      fail(`${at}: startIndex ${s.startIndex}, expected ${expectedStart} (monotone)`);
    }
    expectedStart += s.ayahCount;
    if (!Array.isArray(s.juz) || s.juz.length === 0) fail(`${at}: juz is empty`);
    else {
      for (let k = 0; k < s.juz.length; k += 1) {
        const j = s.juz[k];
        if (!Number.isInteger(j) || j < 1 || j > TOTAL_JUZ) fail(`${at}: juz ${j} out of range`);
        if (k > 0 && j <= s.juz[k - 1]) fail(`${at}: juz not strictly ascending`);
        juzSeen.add(j);
      }
    }
    if (!Array.isArray(s.pages) || s.pages.length !== 2) fail(`${at}: pages is not [first,last]`);
    else {
      const [a, b] = s.pages;
      if (!Number.isInteger(a) || !Number.isInteger(b) || a < 1 || b > TOTAL_PAGES || a > b) {
        fail(`${at}: pages [${a},${b}] out of range 1..${TOTAL_PAGES}`);
      }
    }
  }
  const total = surahs.reduce((a, s) => a + s.ayahCount, 0);
  if (total !== TOTAL_AYAHS) fail(`surahs.json: ayahCount sums to ${total}, expected ${TOTAL_AYAHS}`);
  if (juzSeen.size !== TOTAL_JUZ) fail(`surahs.json: juz coverage is ${juzSeen.size}, expected ${TOTAL_JUZ}`);
  if (surahs[0].pages[0] !== 1) fail("surahs.json: surah 1 does not start on page 1");
  if (surahs[TOTAL_SURAHS - 1].pages[1] !== TOTAL_PAGES) {
    fail(`surahs.json: surah 114 does not end on page ${TOTAL_PAGES}`);
  }
  const g = surahs[1].startIndex + 255 - 1;
  if (g !== 261) fail(`surahs.json: 2:255 maps to global index ${g}, expected 261`);
  ok(
    `surahs.json          ${surahs.length} surahs, ${total} ayat, startIndex monotone, ` +
      `2:255 -> 261, juz 1..${TOTAL_JUZ}, pages 1..${TOTAL_PAGES}`,
  );
}

function verifyRegistry(fail, ok) {
  const file = path.join(OUT, "translations.json");
  const reg = readArray(file, fail);
  if (!reg) return;
  if (reg.length !== TRANSLATION_FILES.length) {
    fail(`translations.json: ${reg.length} entries, expected ${TRANSLATION_FILES.length}`);
  }
  let defaults = 0;
  for (const entry of reg) {
    const at = `translations.json[${entry.id}]`;
    for (const f of REGISTRY_FIELDS) {
      if (!Object.hasOwn(entry, f)) fail(`${at}: missing field "${f}"`);
    }
    if (entry.language !== "en") fail(`${at}: language is "${entry.language}", expected "en"`);
    if (entry.offline !== true) fail(`${at}: offline must be true`);
    if (entry.isDefault) defaults += 1;
    if (!fs.existsSync(path.join(OUT, entry.file))) fail(`${at}: file "${entry.file}" does not exist`);
    for (const f of ["copyright", "attribution", "license", "name", "translator"]) {
      if (typeof entry[f] !== "string" || entry[f].trim() === "") fail(`${at}: "${f}" is empty`);
    }
    const pinned = REQUIRED_STRINGS[entry.id];
    if (!pinned) fail(`${at}: unexpected translation id`);
    else {
      for (const [f, want] of Object.entries(pinned)) {
        if (entry[f] !== want) fail(`${at}: ${f} is "${entry[f]}", expected "${want}"`);
      }
    }
  }
  const ids = reg.map((e) => e.id).join(",");
  if (ids !== "itani,saheeh,ruwwad,pickthall") fail(`translations.json: ids are "${ids}"`);
  if (defaults !== 1) fail(`translations.json: ${defaults} default translations, expected exactly 1`);
  if (reg[0] && reg[0].isDefault !== true) fail("translations.json: itani must be the default");
  ok(`translations.json    ${reg.length} translations, default=itani, all files present`);
}

const EXPECTED_FONTS = [
  { file: "UthmanicHafs1Ver18.ttf", minBytes: 100_000 },
  { file: "UthmanicHafs1Ver18-LICENSE.txt", minBytes: 500 },
  { file: "Amiri-Regular.ttf", minBytes: 100_000 },
  { file: "Amiri-Bold.ttf", minBytes: 100_000 },
  { file: "OFL.txt", minBytes: 500 },
];

function verifyFonts(fail, ok) {
  if (!fs.existsSync(FONTS)) {
    fail("out/fonts is missing");
    return;
  }
  for (const { file, minBytes } of EXPECTED_FONTS) {
    const p = path.join(FONTS, file);
    if (!fs.existsSync(p)) {
      fail(`out/fonts/${file} is missing`);
      continue;
    }
    const size = fs.statSync(p).size;
    if (size < minBytes) fail(`out/fonts/${file} is only ${size} bytes`);
    if (file.endsWith(".ttf")) {
      const head = Buffer.alloc(4);
      const fd = fs.openSync(p, "r");
      fs.readSync(fd, head, 0, 4, 0);
      fs.closeSync(fd);
      const tag = head.toString("hex");
      if (tag !== "00010000" && head.toString("latin1") !== "true" && head.toString("latin1") !== "ttcf") {
        fail(`out/fonts/${file} does not start with a TrueType signature (${tag})`);
      }
    }
  }
  ok(`out/fonts            ${EXPECTED_FONTS.length} files present (2 Arabic families + 2 licences)`);
}

function readJsonIfExists(file) {
  if (!fs.existsSync(file)) return null;
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value)}\n`);
}

const sum = (xs) => xs.reduce((a, b) => a + b, 0);

const code = await main();
process.exit(code ?? 0);
