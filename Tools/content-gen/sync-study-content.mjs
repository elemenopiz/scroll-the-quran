#!/usr/bin/env node
// Copies the assembled pipeline output (out/study shards, passages, discover, themes)
// into the app bundle folder Content/. Idempotent; run after every author wave merge.
//   node Tools/content-gen/sync-study-content.mjs [--check]
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, "out");
const CONTENT = path.join(HERE, "..", "..", "Content");
const check = process.argv.includes("--check");

const pairs = [
  ["study/passages.json", "study/passages.json"],
  ["discover.json", "discover.json"],
  ["themes.json", "themes.json"],
];
for (const f of fs.readdirSync(path.join(OUT, "study"))) {
  if (/^surah_\d{3}\.json$/.test(f)) pairs.push([`study/${f}`, `study/${f}`]);
}

let changed = 0;
for (const [src, dst] of pairs) {
  const a = path.join(OUT, src), b = path.join(CONTENT, dst);
  const next = fs.readFileSync(a, "utf8");
  const cur = fs.existsSync(b) ? fs.readFileSync(b, "utf8") : null;
  if (cur === next) continue;
  changed++;
  if (check) { console.log(`differs: ${dst}`); continue; }
  fs.mkdirSync(path.dirname(b), { recursive: true });
  fs.writeFileSync(b, next);
  console.log(`synced: ${dst}`);
}
// Remove Phase-1 hand fixtures for surahs the pipeline now covers is implicit (same filename).
// Stale fixture shards for surahs with no pipeline shard are left alone but reported.
for (const f of fs.readdirSync(path.join(CONTENT, "study"))) {
  if (/^surah_\d{3}\.json$/.test(f) && !fs.existsSync(path.join(OUT, "study", f))) {
    console.log(`fixture only (no pipeline shard yet): ${f}`);
  }
}
console.log(check ? `${changed} file(s) differ` : `${changed} file(s) synced`);
if (check && changed) process.exit(1);
