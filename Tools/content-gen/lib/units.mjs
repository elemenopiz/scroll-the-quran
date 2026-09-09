// Unit selection shared by build-requests / assemble / judge-sample.
import fs from "node:fs";
import path from "node:path";
import { ROOT, OUT, WORK } from "./data.mjs";

export function loadUnits() {
  const p = path.join(WORK, "units.jsonl");
  if (!fs.existsSync(p)) {
    throw new Error(`${p} missing. Run: node segment-passages.mjs`);
  }
  return fs
    .readFileSync(p, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((l) => JSON.parse(l));
}

export function loadPassages() {
  const p = path.join(OUT, "study", "passages.json");
  if (!fs.existsSync(p)) throw new Error(`${p} missing. Run: node segment-passages.mjs`);
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

/** Discover seed refs -> ordered, de-duplicated unit keys. */
export function discoverKeys() {
  const passages = loadPassages();
  const seed = fs.readFileSync(path.join(ROOT, "discover-seed.txt"), "utf8");
  const keys = [];
  const seen = new Set();
  const missing = [];
  for (const raw of seed.split("\n")) {
    const line = raw.replace(/#.*/, "").trim();
    if (!line) continue;
    const unit = passages[line];
    if (!unit) {
      missing.push(line);
      continue;
    }
    if (!seen.has(unit)) {
      seen.add(unit);
      keys.push(unit);
    }
  }
  if (missing.length) {
    throw new Error(`discover-seed.txt references non-existent ayat: ${missing.join(", ")}`);
  }
  return keys;
}

/**
 * @param {string} only "discover" | "all" | "surah:N"
 * @returns units in file order, each tagged with its tier.
 */
export function selectUnits(only) {
  const units = loadUnits();
  const discover = new Set(discoverKeys());
  const tag = (u) => ({
    ...u,
    tier: discover.has(u.key) ? "discover" : u.named ? "core" : "standard",
  });

  if (only === "all") return units.map(tag);
  if (only === "discover") {
    const byKey = new Map(units.map((u) => [u.key, u]));
    return discoverKeys().map((k) => {
      const u = byKey.get(k);
      if (!u) throw new Error(`discover unit ${k} not present in units.jsonl`);
      return tag(u);
    });
  }
  const m = /^surah:(\d{1,3})$/.exec(only ?? "");
  if (m) return units.filter((u) => u.surah === Number(m[1])).map(tag);
  throw new Error(`--only must be "discover", "all", or "surah:N" (got ${JSON.stringify(only)})`);
}
