#!/usr/bin/env node
// Grades generated study notes against a rubric using Claude Opus 5.
//
//   node judge-sample.mjs --dry-run --sample 0.05
//   zsh -c 'source ~/.zshrc; node judge-sample.mjs --sample 0.05 --confirm'
//
// Every Discover-tier unit is always graded; --sample adds that fraction of
// the rest. Anything scoring below 4/5 overall is listed for regeneration at
// higher effort. Results land in work/judge/<key>.json.
import fs from "node:fs";
import path from "node:path";
import { OUT, WORK, loadQuran } from "./lib/data.mjs";
import { selectUnits } from "./lib/units.mjs";
import { estimateCost, usd, THINKING_TOKENS_BY_EFFORT } from "./lib/pricing.mjs";

const DEFAULT_MODEL = "claude-opus-5";
const CONCURRENCY = 4;
const PASS_MARK = 4;

const RUBRIC = `You are reviewing a short study note about a passage of the Quran, written for a general-audience mobile app. Score it honestly; the notes are AI-generated and the point of this pass is to catch the weak ones.

Score each criterion from 1 to 5.

- accuracy: is everything stated about the passage, its context, and its language correct and consistent with mainstream classical exegesis (Ibn Kathir, al-Tabari, al-Qurtubi, al-Sa'di)? Any invented detail, misattributed occasion of revelation, or wrong claim about the Arabic scores 2 or below.
- nonSectarian: does it stay on common ground, without favouring a school, sect, or movement, and without issuing legal rulings or telling the reader what is required of them?
- groundedness: is the historical context and the occasion of revelation attested rather than guessed? Is "scholars differ" used where they genuinely do?
- languageQuality: are the key Arabic terms actually present in the passage, correctly glossed, and is the English prose free of Arabic script and transliteration?
- usefulness: does the note tell the reader something they did not already have, and is applyIt concrete, second-person, and not a ruling?
- toneFit: warm, direct, unhurried; no preaching outside applyIt, no filler openers, no marketing language.

overall is your holistic 1-5 judgement, not an average. Notes must state, in one or two sentences each, every concrete problem you found. If you found none, say so plainly.`;

const JUDGE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["accuracy", "nonSectarian", "groundedness", "languageQuality", "usefulness", "toneFit", "overall", "notes"],
  properties: {
    accuracy: { type: "integer", minimum: 1, maximum: 5 },
    nonSectarian: { type: "integer", minimum: 1, maximum: 5 },
    groundedness: { type: "integer", minimum: 1, maximum: 5 },
    languageQuality: { type: "integer", minimum: 1, maximum: 5 },
    usefulness: { type: "integer", minimum: 1, maximum: 5 },
    toneFit: { type: "integer", minimum: 1, maximum: 5 },
    overall: { type: "integer", minimum: 1, maximum: 5 },
    notes: { type: "array", items: { type: "string" }, minItems: 1, maxItems: 8 },
  },
};

function loadStudies() {
  const dir = path.join(OUT, "study");
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const f of fs.readdirSync(dir).filter((f) => /^surah_\d{3}\.json$/.test(f)).sort()) {
    const shard = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
    out.push(...shard.studies);
  }
  return out;
}

/** Deterministic 0..1 hash so the same sample is chosen on every run. */
function hash01(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 100000) / 100000;
}

export function pickSample(studies, fraction) {
  return studies.filter((s) => s.tier === "discover" || hash01(s.key) < fraction);
}

function userTurn(study, quran) {
  const p = { surah: study.surah, start: study.start, end: study.end };
  const english = [];
  for (let a = p.start; a <= p.end; a++) english.push(`${a}. ${quran.english(p.surah, a)}`);
  return [
    `## Passage ${study.key}`,
    "",
    english.join("\n"),
    "",
    "## Study note under review",
    "",
    "```json",
    JSON.stringify(study, null, 2),
    "```",
    "",
    "Score it against the rubric.",
  ].join("\n");
}

async function main(argv = process.argv.slice(2)) {
  const get = (f, d) => {
    const i = argv.indexOf(f);
    return i === -1 ? d : argv[i + 1];
  };
  const model = get("--model", DEFAULT_MODEL);
  const fraction = Number(get("--sample", 0.05));
  const effort = get("--effort", "high");
  const dryRun = argv.includes("--dry-run");
  const confirm = argv.includes("--confirm");
  const maxCost = Number(get("--max-cost", 15));

  const quran = loadQuran();
  const studies = loadStudies();
  const sample = pickSample(studies, fraction);

  const perRequestInput = sample.length
    ? sample.reduce((n, s) => n + Math.ceil((RUBRIC.length + userTurn(s, quran).length) / 3.6), 0) / sample.length
    : 0;
  const est = estimateCost({
    model,
    requests: sample.length,
    cachedSystemTokens: Math.ceil(RUBRIC.length / 3.6),
    uncachedInputTokens: Math.max(0, perRequestInput - Math.ceil(RUBRIC.length / 3.6)),
    outputTokens: 250 + THINKING_TOKENS_BY_EFFORT[effort],
    batch: false,
  });

  console.log(`studies on disk:  ${studies.length}`);
  console.log(`  discover tier:  ${studies.filter((s) => s.tier === "discover").length} (always judged)`);
  console.log(`  --sample ${fraction} of the rest`);
  console.log(`to judge:         ${sample.length}`);
  console.log(`model:            ${model}  effort: ${effort}`);
  console.log(`estimated cost:   ${usd(est.total)} (no batch discount — these are live calls)`);

  if (dryRun) {
    console.log("\n--dry-run: no API call made.");
    return;
  }
  if (!sample.length) {
    console.log("\nnothing to judge.");
    return;
  }
  if (est.total > maxCost && !confirm) {
    console.error(`\nEstimated ${usd(est.total)} exceeds --max-cost $${maxCost}. Re-run with --confirm.`);
    process.exit(1);
  }
  if (process.env.ANTHROPIC_BASE_URL && !/api\.anthropic\.com/.test(process.env.ANTHROPIC_BASE_URL)) {
    console.error(`\nANTHROPIC_BASE_URL is ${process.env.ANTHROPIC_BASE_URL}, not the Anthropic API. Refusing.`);
    process.exit(1);
  }

  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const client = new Anthropic();
  const dir = path.join(WORK, "judge");
  fs.mkdirSync(dir, { recursive: true });

  const results = [];
  let cursor = 0;
  const worker = async () => {
    while (cursor < sample.length) {
      const study = sample[cursor++];
      try {
        const res = await client.messages.create({
          model,
          max_tokens: 8000,
          system: [{ type: "text", text: RUBRIC, cache_control: { type: "ephemeral" } }],
          output_config: { effort, format: { type: "json_schema", schema: JUDGE_SCHEMA } },
          messages: [{ role: "user", content: userTurn(study, quran) }],
        });
        const text = res.content.find((b) => b.type === "text")?.text;
        const score = JSON.parse(text);
        fs.writeFileSync(path.join(dir, `${study.key.replace(":", "_")}.json`),
          JSON.stringify({ key: study.key, model, score, judgedAt: new Date().toISOString() }, null, 2) + "\n");
        results.push({ key: study.key, ...score });
        process.stdout.write(`${results.length}/${sample.length} `);
      } catch (e) {
        console.error(`\n! ${study.key}: ${e.message}`);
      }
    }
  };
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  console.log("\n");
  const mean = (f) => (results.reduce((n, r) => n + r[f], 0) / results.length).toFixed(2);
  for (const f of ["accuracy", "nonSectarian", "groundedness", "languageQuality", "usefulness", "toneFit", "overall"]) {
    console.log(`  ${f.padEnd(16)} ${mean(f)}`);
  }
  const failing = results.filter((r) => r.overall < PASS_MARK);
  console.log(`\nbelow ${PASS_MARK}/5: ${failing.length}`);
  for (const f of failing) console.log(`  ${f.key}  overall=${f.overall}  ${f.notes[0]}`);
  if (failing.length) {
    console.log(`\nregenerate with: node build-requests.mjs --only discover --effort xhigh --force`);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
export { main, JUDGE_SCHEMA, RUBRIC };
