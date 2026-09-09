#!/usr/bin/env node
// Turns work/cache/*.json (raw batch results) into the committed content:
//
//   out/study/surah_NNN.json   { surah, promptVersion, generatedAt, studies: [...] }
//   out/discover.json          the curated Discover feed manifest
//
//   node assemble.mjs                       # all cached results
//   node assemble.mjs --model claude-opus-5 --only discover
//
// Shard studies are sorted by start ayah; every field order follows
// schema/study.schema.json's x-sectionOrder so diffs stay stable.
import fs from "node:fs";
import path from "node:path";
import { ROOT, OUT, loadQuran, parseKey } from "./lib/data.mjs";
import { selectUnits, discoverKeys } from "./lib/units.mjs";
import { PROMPT_VERSION } from "./lib/prompt.mjs";
import { cacheDir } from "./build-requests.mjs";

const SCHEMA = JSON.parse(fs.readFileSync(path.join(ROOT, "schema", "study.schema.json"), "utf8"));
const FIELD_ORDER = [
  "key", "surah", "start", "end", "theme", "themeId", "title", "tier",
  ...SCHEMA["x-sectionOrder"], "meta",
];

export function loadCache({ model = null, promptVersion = PROMPT_VERSION } = {}) {
  const dir = cacheDir();
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))
    .filter((r) => (!model || r.model === model) && (!promptVersion || r.promptVersion === promptVersion));
}

export function assembleStudy(cached, unit) {
  const p = parseKey(cached.key);
  const merged = {
    ...cached.body,
    key: cached.key,
    surah: p.surah,
    start: p.start,
    end: p.end,
    tier: unit?.tier ?? "standard",
    meta: {
      model: cached.model,
      promptVersion: cached.promptVersion,
      generatedAt: cached.receivedAt ?? new Date().toISOString(),
      reviewed: false,
    },
  };
  const ordered = {};
  for (const f of FIELD_ORDER) if (f in merged) ordered[f] = merged[f];
  for (const f of Object.keys(merged)) if (!(f in ordered)) ordered[f] = merged[f];
  return ordered;
}

function main(argv = process.argv.slice(2)) {
  const get = (f, d) => {
    const i = argv.indexOf(f);
    return i === -1 ? d : argv[i + 1];
  };
  const model = get("--model", null);
  const only = get("--only", "all");

  loadQuran();
  const units = new Map(selectUnits("all").map((u) => [u.key, u]));
  const wanted = only === "all" ? null : new Set(selectUnits(only).map((u) => u.key));

  const cached = loadCache({ model }).filter((r) => !wanted || wanted.has(r.key));

  // Merge-aware: start from every shard already committed in out/study, then let
  // cached results replace or add studies by key. Parallel author waves therefore
  // never drop each other's work, and shards nobody touched keep their generatedAt.
  const studyDir = path.join(OUT, "study");
  fs.mkdirSync(studyDir, { recursive: true });
  const existing = new Map(); // surah -> { generatedAt, byKey: Map }
  for (const f of fs.readdirSync(studyDir)) {
    const m = /^surah_(\d{3})\.json$/.exec(f);
    if (!m) continue;
    const shard = JSON.parse(fs.readFileSync(path.join(studyDir, f), "utf8"));
    const byKey = new Map((shard.studies ?? []).map((st) => [st.key, st]));
    existing.set(Number(m[1]), { generatedAt: shard.generatedAt, byKey });
  }
  const bySurah = new Map([...existing].map(([surah, e]) => [surah, new Map(e.byKey)]));
  const touched = new Set();
  for (const c of cached) {
    const study = assembleStudy(c, units.get(c.key));
    const map = bySurah.get(study.surah) ?? new Map();
    const before = map.get(study.key);
    map.set(study.key, study);
    bySurah.set(study.surah, map);
    if (JSON.stringify(before) !== JSON.stringify(study)) touched.add(study.surah);
  }

  const shardFiles = [];
  for (const [surah, map] of [...bySurah].sort((a, b) => a[0] - b[0])) {
    const studies = [...map.values()].sort((a, b) => a.start - b.start || a.end - b.end);
    const file = path.join(studyDir, `surah_${String(surah).padStart(3, "0")}.json`);
    const generatedAt = touched.has(surah) || !existing.get(surah)?.generatedAt
      ? new Date().toISOString()
      : existing.get(surah).generatedAt;
    const json = JSON.stringify({ surah, promptVersion: PROMPT_VERSION, generatedAt, studies }, null, 2) + "\n";
    if (!fs.existsSync(file) || fs.readFileSync(file, "utf8") !== json) fs.writeFileSync(file, json);
    shardFiles.push({ file, count: studies.length, touched: touched.has(surah) });
  }

  // Discover manifest, from the merged corpus (not just this run's cache).
  const all = new Map();
  for (const map of bySurah.values()) for (const [k, st] of map) all.set(k, st);
  const generated = new Set(all.keys());
  const keys = discoverKeys();
  const present = keys.filter((k) => generated.has(k));
  const missing = keys.filter((k) => !generated.has(k));
  const items = present.map((k) => {
    const s = all.get(k);
    return { key: k, surah: s.surah, start: s.start, end: s.end, themeId: s.themeId, title: s.title };
  });
  {
    const discoverFile = path.join(OUT, "discover.json");
    const prev = fs.existsSync(discoverFile) ? JSON.parse(fs.readFileSync(discoverFile, "utf8")) : null;
    const unchanged = prev && JSON.stringify(prev.items) === JSON.stringify(items);
    const generatedAt = unchanged ? prev.generatedAt : new Date().toISOString();
    const json = JSON.stringify(
      { seed: "discover-seed.txt", promptVersion: PROMPT_VERSION, generatedAt, count: items.length, items },
      null, 2,
    ) + "\n";
    if (!fs.existsSync(discoverFile) || fs.readFileSync(discoverFile, "utf8") !== json) fs.writeFileSync(discoverFile, json);
  }

  console.log(`cached results:   ${cached.length}${model ? ` (model ${model})` : ""}`);
  console.log(`assembled corpus: ${all.size} studies across ${shardFiles.length} shards (${[...touched].length} touched this run)`);
  console.log(`surah shards:     ${shardFiles.length}`);
  for (const s of shardFiles.slice(0, 10)) {
    console.log(`  ${path.relative(process.cwd(), s.file)}  (${s.count})`);
  }
  if (shardFiles.length > 10) console.log(`  … ${shardFiles.length - 10} more`);
  console.log(`discover seed:    ${keys.length} units`);
  console.log(`  assembled:      ${items.length}`);
  console.log(`  missing:        ${missing.length}${missing.length ? ` (${missing.slice(0, 8).join(", ")}${missing.length > 8 ? ", …" : ""})` : ""}`);
  console.log(`wrote out/discover.json`);
  console.log(`\nnext: node validate.mjs out/study`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
export { main };
