// resolve.mjs — replace keyTerms[].arabic placeholders "@S:A/i" or "@S:A/i-j"
// with the exact Uthmani token(s) from the corpus, so no Arabic is ever
// transcribed by hand. Idempotent: entries already in Arabic script are left.
import fs from "node:fs";
import path from "node:path";
import { loadQuran } from "./lib/data.mjs";
const q = loadQuran();
const dir = process.argv[2];
if (!dir) { console.error("usage: node resolve.mjs <dir>"); process.exit(2); }
let changed = 0, bad = 0;
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith(".json")).sort()) {
  const p = path.join(dir, f);
  const body = JSON.parse(fs.readFileSync(p, "utf8"));
  for (const [i, t] of (body.keyTerms || []).entries()) {
    const m = /^@(\d+):(\d+)\/(\d+)(?:-(\d+))?$/.exec(String(t.arabic || ""));
    if (!m) continue;
    const [, s, a, lo, hi] = m;
    const toks = String(q.uthmani(Number(s), Number(a))).split(/\s+/);
    const from = Number(lo), to = hi === undefined ? from : Number(hi);
    if (to >= toks.length) { console.log(`  ✗ ${f} keyTerms[${i}]: ${t.arabic} out of range (${toks.length} tokens)`); bad++; continue; }
    t.arabic = toks.slice(from, to + 1).join(" ");
    console.log(`  ${f} keyTerms[${i}] -> ${t.arabic}`);
    changed++;
  }
  fs.writeFileSync(p, JSON.stringify(body, null, 2) + "\n");
}
console.log(`resolved ${changed} placeholder(s), ${bad} bad`);
process.exit(bad ? 1 : 0);
