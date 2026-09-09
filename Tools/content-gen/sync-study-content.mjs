#!/usr/bin/env node
// Copies the assembled pipeline output (out/study shards, passages, discover, themes)
// into the app bundle folder Content/. Idempotent; run after every author wave merge.
//   node Tools/content-gen/sync-study-content.mjs [--check] [--prune]
//
//   --check   report what would change, write nothing, exit non-zero if anything would
//   --prune   delete Content/study shards the pipeline no longer produces (the Phase-1
//             hand fixtures), so Content/study is exactly the pipeline's output
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, "out");
const CONTENT = path.join(HERE, "..", "..", "Content");
const check = process.argv.includes("--check");
const prune = process.argv.includes("--prune");

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
// A surah the pipeline now covers is replaced above (same filename). A shard with no pipeline
// counterpart is a leftover Phase-1 hand fixture in an obsolete shape: --prune deletes it, so
// Content/study holds exactly what the pipeline produces and the app never ships a shard that
// cannot be regenerated.
for (const f of fs.readdirSync(path.join(CONTENT, "study")).sort()) {
  if (!/^surah_\d{3}\.json$/.test(f)) continue;
  if (fs.existsSync(path.join(OUT, "study", f))) continue;
  if (!prune) {
    console.log(`fixture only (no pipeline shard; pass --prune to delete): ${f}`);
    continue;
  }
  changed++;
  if (check) { console.log(`stale: study/${f}`); continue; }
  fs.rmSync(path.join(CONTENT, "study", f));
  console.log(`pruned: study/${f}`);
}
console.log(check ? `${changed} file(s) differ` : `${changed} file(s) synced`);
if (check && changed) process.exit(1);
