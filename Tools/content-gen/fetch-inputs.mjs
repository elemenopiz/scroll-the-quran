#!/usr/bin/env node
// Downloads the Quran text this pipeline needs into `work/quran/` (gitignored).
//
// This is a stopgap for running before the 2a ingest task lands. Once
// `out/quran/{surahs,itani,arabic-uthmani}.json` exist, they take precedence
// and this script is unnecessary. Sources match docs/tasks/phase2a-data-ingest.md.
import fs from "node:fs";
import path from "node:path";
import { WORK } from "./lib/data.mjs";

const FILES = [
  ["itani.raw.json", "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-talalitani.json"],
  ["arabic.raw.json", "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranuthmanihaf.json"],
  ["quran-data.xml", "https://tanzil.net/res/text/metadata/quran-data.xml"],
];

const dir = path.join(WORK, "quran");
fs.mkdirSync(dir, { recursive: true });

for (const [name, url] of FILES) {
  const dest = path.join(dir, name);
  if (fs.existsSync(dest) && !process.argv.includes("--force")) {
    console.log(`skip  ${name} (already present; --force to refetch)`);
    continue;
  }
  process.stdout.write(`fetch ${name} … `);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url} -> HTTP ${res.status}`);
  fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
  console.log(`${(fs.statSync(dest).size / 1024).toFixed(0)} KB`);
}
console.log("done. Sources: fawazahmed0/quran-api (Itani, Uthmani Hafs), Tanzil quran-data.xml (CC BY 3.0).");
