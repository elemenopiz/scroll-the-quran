// toks.mjs — print every token of the given ayat, one per line, index-prefixed.
import { loadQuran } from "./lib/data.mjs";
const q = loadQuran();
for (const spec of process.argv.slice(2)) {
  const [s, a] = spec.split(":").map(Number);
  const toks = String(q.uthmani(s, a)).split(/\s+/);
  toks.forEach((t, i) => console.log(`${s}:${a}\t${i}\t${t}`));
}
