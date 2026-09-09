#!/usr/bin/env node
// Deterministic passage segmentation — no LLM, no network.
//
// Rules (docs/tasks/phase2b-pipeline-scripts.md §1):
//   * an ayah of >= 12 words is its own study unit;
//   * shorter ayat merge with their neighbours, up to 5 ayat / 60 words;
//   * units never span a surah boundary;
//   * every range in named-passages.json is exactly one unit and is never
//     split or absorbed.
//
// Outputs:
//   out/study/passages.json  { "<surah>:<ayah>": "<unitKey>", … }  (all 6,236)
//   work/units.jsonl         one JSON object per unit (gitignored working set)
import fs from "node:fs";
import path from "node:path";
import { ROOT, OUT, WORK, loadQuran, unitKey, parseKey, words } from "./lib/data.mjs";

export const DEFAULTS = { minOwnWords: 24, maxAyat: 5, maxWords: 60 };

/** Load and validate named-passages.json into a per-surah map of fixed ranges. */
export function loadNamedPassages(byNumber, file = path.join(ROOT, "named-passages.json")) {
  const raw = JSON.parse(fs.readFileSync(file, "utf8"));
  const bySurah = new Map();
  for (const entry of raw.passages) {
    const p = parseKey(entry.key);
    if (!p) throw new Error(`named-passages.json: unparseable key ${entry.key}`);
    const surah = byNumber.get(p.surah);
    if (!surah) throw new Error(`named-passages.json: no surah ${p.surah}`);
    if (p.end > surah.ayahCount) {
      throw new Error(`named-passages.json: ${entry.key} exceeds surah length (${surah.ayahCount})`);
    }
    const list = bySurah.get(p.surah) ?? [];
    list.push({ ...p, name: entry.name });
    bySurah.set(p.surah, list);
  }
  for (const [n, list] of bySurah) {
    list.sort((a, b) => a.start - b.start);
    for (let i = 1; i < list.length; i++) {
      if (list[i].start <= list[i - 1].end) {
        throw new Error(`named-passages.json: overlapping ranges in surah ${n}`);
      }
    }
  }
  return bySurah;
}

/** Greedy left-to-right segmentation of a contiguous run [from,to] of one surah. */
function segmentRun(surahNumber, from, to, wordsAt, opts) {
  const { minOwnWords: MIN_OWN_UNIT_WORDS, maxAyat: MAX_UNIT_AYAT, maxWords: MAX_UNIT_WORDS } = opts;
  const units = [];
  let i = from;
  while (i <= to) {
    if (wordsAt(i) >= MIN_OWN_UNIT_WORDS) {
      units.push({ start: i, end: i, words: wordsAt(i) });
      i++;
      continue;
    }
    let end = i;
    let total = wordsAt(i);
    while (
      end + 1 <= to &&
      end + 1 - i + 1 <= MAX_UNIT_AYAT &&
      wordsAt(end + 1) < MIN_OWN_UNIT_WORDS &&
      total + wordsAt(end + 1) <= MAX_UNIT_WORDS
    ) {
      end++;
      total += wordsAt(end);
    }
    units.push({ start: i, end, words: total });
    i = end + 1;
  }
  // Second pass: an isolated unit still under the minimum absorbs into the
  // neighbour it fits best with (previous first, then next) while staying
  // inside the 5-ayah / 60-word envelope.
  for (let k = 0; k < units.length; k++) {
    if (units[k].words >= MIN_OWN_UNIT_WORDS) continue;
    const fits = (a, b) =>
      a && b && b.end - a.start + 1 <= MAX_UNIT_AYAT && a.words + b.words <= MAX_UNIT_WORDS;
    const prev = units[k - 1];
    const next = units[k + 1];
    if (fits(prev, units[k])) {
      prev.end = units[k].end;
      prev.words += units[k].words;
      units.splice(k, 1);
      k--;
    } else if (fits(units[k], next)) {
      units[k].end = next.end;
      units[k].words += next.words;
      units.splice(k + 1, 1);
    }
  }
  return units.map((u) => ({ surah: surahNumber, ...u }));
}

export function segment(quran, namedBySurah, opts = DEFAULTS) {
  const units = [];
  for (const surah of quran.surahs) {
    const wordsAt = (ayah) => words(quran.english(surah.number, ayah));
    const named = namedBySurah.get(surah.number) ?? [];
    let cursor = 1;
    for (const n of named) {
      if (n.start > cursor) units.push(...segmentRun(surah.number, cursor, n.start - 1, wordsAt, opts));
      let total = 0;
      for (let a = n.start; a <= n.end; a++) total += wordsAt(a);
      units.push({ surah: surah.number, start: n.start, end: n.end, words: total, named: n.name });
      cursor = n.end + 1;
    }
    if (cursor <= surah.ayahCount) {
      units.push(...segmentRun(surah.number, cursor, surah.ayahCount, wordsAt, opts));
    }
  }
  return units;
}

function parseArgs(argv) {
  const opts = { ...DEFAULTS };
  const num = (flag, key) => {
    const i = argv.indexOf(flag);
    if (i !== -1) opts[key] = Number(argv[i + 1]);
  };
  num("--min-own-words", "minOwnWords");
  num("--max-ayat", "maxAyat");
  num("--max-words", "maxWords");
  return opts;
}

function main(argv = process.argv.slice(2)) {
  const opts = parseArgs(argv);
  const quran = loadQuran();
  const named = loadNamedPassages(quran.byNumber);

  if (argv.includes("--stats")) {
    console.log("unit-count sensitivity (minOwnWords x maxWords):");
    for (const m of [12, 16, 20, 24]) {
      const row = [30, 45, 60, 90].map((w) => {
        const n = segment(quran, named, { ...opts, minOwnWords: m, maxWords: w }).length;
        return `maxWords=${w}: ${String(n).padStart(5)}`;
      });
      console.log(`  minOwnWords=${String(m).padStart(2)}  ${row.join("  ")}`);
    }
    return;
  }

  const units = segment(quran, named, opts);

  // Invariants.
  const covered = new Set();
  for (const u of units) {
    if (u.end < u.start) throw new Error(`bad unit ${JSON.stringify(u)}`);
    for (let a = u.start; a <= u.end; a++) {
      const k = `${u.surah}:${a}`;
      if (covered.has(k)) throw new Error(`ayah ${k} covered twice`);
      covered.add(k);
    }
  }
  if (covered.size !== 6236) throw new Error(`covered ${covered.size} ayat, expected 6236`);

  const passages = {};
  const lines = [];
  for (const u of units) {
    const key = unitKey(u.surah, u.start, u.end);
    for (let a = u.start; a <= u.end; a++) passages[`${u.surah}:${a}`] = key;
    lines.push(
      JSON.stringify({
        key,
        surah: u.surah,
        start: u.start,
        end: u.end,
        ayatCount: u.end - u.start + 1,
        words: u.words,
        named: u.named ?? null,
      }),
    );
  }

  fs.mkdirSync(path.join(OUT, "study"), { recursive: true });
  fs.mkdirSync(WORK, { recursive: true });
  fs.writeFileSync(path.join(OUT, "study", "passages.json"), JSON.stringify(passages, null, 0) + "\n");
  fs.writeFileSync(path.join(WORK, "units.jsonl"), lines.join("\n") + "\n");

  const multi = units.filter((u) => u.end > u.start).length;
  const maxWords = Math.max(...units.map((u) => u.words));
  console.log(`thresholds:       minOwnWords=${opts.minOwnWords} maxAyat=${opts.maxAyat} maxWords=${opts.maxWords}`);
  console.log(`units:            ${units.length}`);
  console.log(`  single-ayah:    ${units.length - multi}`);
  console.log(`  multi-ayah:     ${multi}`);
  console.log(`  named passages: ${units.filter((u) => u.named).length}`);
  console.log(`  max words/unit: ${maxWords}`);
  console.log(`ayat covered:     ${covered.size}`);
  console.log(`wrote out/study/passages.json and work/units.jsonl`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
