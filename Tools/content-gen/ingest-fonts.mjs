#!/usr/bin/env node
// Scroll the Quran - Arabic font ingest.
//
//   node Tools/content-gen/ingest-fonts.mjs --fetch    download fonts + licences into out/fonts
//   node Tools/content-gen/ingest-fonts.mjs --names    print family / PostScript names from disk
//
// Fonts:
//   KFGQPC Uthmanic Hafs v18  - the Quran text face (primary Arabic layer)
//   Amiri Regular + Bold      - OFL fallback face
//
// Node 24 built-ins only. The KFGQPC EULA has no standalone text file upstream, so
// it is extracted from the font's own `name` table (name IDs 0 and 13) at ingest time.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

import { fetchBuffer } from "./lib/fetch-util.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, "out", "fonts");
const RAW = path.join(HERE, "work", "raw");

export const FONT_SOURCES = {
  hafs: {
    url: "https://verses.quran.foundation/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.ttf",
    mirror: "https://github.com/nuqayah/qpc-fonts",
    file: "UthmanicHafs1Ver18.ttf",
  },
  amiri: {
    url: "https://github.com/aliftype/amiri/releases/download/1.003/Amiri-1.003.zip",
    version: "1.003",
    members: {
      "Amiri-1.003/Amiri-Regular.ttf": "Amiri-Regular.ttf",
      "Amiri-1.003/Amiri-Bold.ttf": "Amiri-Bold.ttf",
      "Amiri-1.003/OFL.txt": "OFL.txt",
    },
  },
};

async function main() {
  const argv = process.argv.slice(2);
  if (argv.includes("--fetch")) await runFetch();
  if (argv.includes("--names") || argv.includes("--fetch")) printNames();
  if (argv.length === 0) {
    console.error("usage: ingest-fonts.mjs [--fetch] [--names]");
    process.exit(2);
  }
}

async function runFetch() {
  fs.mkdirSync(OUT, { recursive: true });
  fs.mkdirSync(RAW, { recursive: true });

  // --- KFGQPC Uthmanic Hafs
  const hafsPath = path.join(OUT, FONT_SOURCES.hafs.file);
  const hafs = await fetchBuffer(FONT_SOURCES.hafs.url);
  if (hafs.readUInt32BE(0) !== 0x00010000) {
    throw new Error(`${FONT_SOURCES.hafs.url} did not return a TrueType file`);
  }
  fs.writeFileSync(hafsPath, hafs);
  console.log(`out/fonts/${FONT_SOURCES.hafs.file}  ${hafs.length} bytes`);
  writeHafsLicense(hafsPath);

  // --- Amiri (zip -> selected members)
  const zipPath = path.join(RAW, `Amiri-${FONT_SOURCES.amiri.version}.zip`);
  if (!fs.existsSync(zipPath)) {
    fs.writeFileSync(zipPath, await fetchBuffer(FONT_SOURCES.amiri.url));
  }
  for (const [member, target] of Object.entries(FONT_SOURCES.amiri.members)) {
    // `unzip -p` streams one member to stdout; no archive library needed.
    const buf = execFileSync("unzip", ["-p", zipPath, member], { maxBuffer: 64 * 1024 * 1024 });
    if (buf.length === 0) throw new Error(`Amiri zip: member ${member} is empty or missing`);
    fs.writeFileSync(path.join(OUT, target), buf);
    console.log(`out/fonts/${target}  ${buf.length} bytes`);
  }
}

/** Pull the KFGQPC copyright + EULA out of the font's own name table. */
function writeHafsLicense(ttfPath) {
  const names = readNameTable(ttfPath);
  const copyright = names.get(0) ?? "";
  const eula = names.get(13) ?? "";
  const body = [
    "KFGQPC Uthmanic Hafs (UthmanicHafs1Ver18.ttf)",
    "",
    `Family name:     ${names.get(1) ?? "?"}`,
    `Full name:       ${names.get(4) ?? "?"}`,
    `PostScript name: ${names.get(6) ?? "?"}`,
    `Version:         ${names.get(5) ?? "?"}`,
    "",
    `Downloaded from: ${FONT_SOURCES.hafs.url}`,
    `Mirror:          ${FONT_SOURCES.hafs.mirror}`,
    "",
    "The licence below is reproduced verbatim from the font's own `name` table",
    "(name ID 0 = copyright notice, name ID 13 = licence description); the King Fahd",
    "Glorious Quran Printing Complex does not publish a separate licence file.",
    "",
    "--- name ID 0: copyright notice -------------------------------------------",
    "",
    copyright,
    "",
    "--- name ID 13: licence description ---------------------------------------",
    "",
    eula,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(OUT, "UthmanicHafs1Ver18-LICENSE.txt"), body.replace(/\r\n/g, "\n"));
  console.log("out/fonts/UthmanicHafs1Ver18-LICENSE.txt  (extracted from name table)");
}

/**
 * Minimal TrueType `name` table reader: enough to pull the standard name IDs.
 * Returns a Map of nameID -> string, preferring Windows/Unicode (UTF-16BE) records.
 */
export function readNameTable(file) {
  const buf = fs.readFileSync(file);
  const numTables = buf.readUInt16BE(4);
  let nameOffset = -1;
  for (let i = 0; i < numTables; i += 1) {
    const rec = 12 + i * 16;
    if (buf.toString("latin1", rec, rec + 4) === "name") {
      nameOffset = buf.readUInt32BE(rec + 8);
      break;
    }
  }
  if (nameOffset < 0) throw new Error(`${file}: no name table`);
  const count = buf.readUInt16BE(nameOffset + 2);
  const stringOffset = nameOffset + buf.readUInt16BE(nameOffset + 4);
  const out = new Map();
  for (let i = 0; i < count; i += 1) {
    const rec = nameOffset + 6 + i * 12;
    const platformID = buf.readUInt16BE(rec);
    const encodingID = buf.readUInt16BE(rec + 2);
    const languageID = buf.readUInt16BE(rec + 4);
    const nameID = buf.readUInt16BE(rec + 6);
    const length = buf.readUInt16BE(rec + 8);
    const offset = buf.readUInt16BE(rec + 10);
    const slice = buf.subarray(stringOffset + offset, stringOffset + offset + length);
    const unicode = platformID === 3 || platformID === 0;
    const value = unicode ? slice.swap16().toString("utf16le") : slice.toString("latin1");
    const english = languageID === 0x0409 || languageID === 0 || platformID === 1;
    if (!out.has(nameID) || (unicode && english)) out.set(nameID, value);
  }
  return out;
}

const NAME_IDS = [
  [1, "Family"],
  [2, "Subfamily"],
  [4, "Full name"],
  [6, "PostScript name"],
  [5, "Version"],
  [16, "Typographic family"],
  [17, "Typographic subfamily"],
];

function printNames() {
  console.log("\nFont names (from each file's `name` table):");
  for (const file of fs.readdirSync(OUT).filter((f) => f.endsWith(".ttf")).sort()) {
    const names = readNameTable(path.join(OUT, file));
    console.log(`\n  ${file}`);
    for (const [id, label] of NAME_IDS) {
      const v = names.get(id);
      if (v) console.log(`    ${label.padEnd(22)} ${v}`);
    }
  }
  console.log("");
}

await main();
