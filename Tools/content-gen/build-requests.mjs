#!/usr/bin/env node
// Builds Message Batches request records for the Deep Study pipeline.
//
//   node build-requests.mjs --dry-run --only discover
//   node build-requests.mjs --only discover            # writes work/requests/<name>.jsonl
//
// Nothing here calls the paid API. --dry-run additionally refuses to write
// anything and just prints the estimate. Token counts come from the free
// /v1/messages/count_tokens endpoint when a credential is available, and from
// a character heuristic otherwise.
import fs from "node:fs";
import path from "node:path";
import { OUT, WORK, loadQuran } from "./lib/data.mjs";
import { selectUnits } from "./lib/units.mjs";
import {
  PROMPT_VERSION, buildSystem, buildUserTurn, buildOutputSchema,
  encodeCustomId, logicalCustomId,
} from "./lib/prompt.mjs";
import { estimateCost, usd, THINKING_TOKENS_BY_EFFORT, priceFor } from "./lib/pricing.mjs";

const DEFAULT_MODEL = "claude-opus-5";
const DEFAULT_EFFORT = "medium";
const DEFAULT_MAX_TOKENS = 8000;
/** JSON body of one study note, measured on the schema's word bounds. */
const ESTIMATED_JSON_OUTPUT_TOKENS = 800;

export function parseArgs(argv) {
  const get = (flag, fallback) => {
    const i = argv.indexOf(flag);
    return i === -1 ? fallback : argv[i + 1];
  };
  return {
    model: get("--model", DEFAULT_MODEL),
    only: get("--only", "discover"),
    effort: get("--effort", DEFAULT_EFFORT),
    maxTokens: Number(get("--max-tokens", DEFAULT_MAX_TOKENS)),
    limit: argv.includes("--limit") ? Number(get("--limit")) : null,
    out: get("--out", null),
    dryRun: argv.includes("--dry-run"),
    force: argv.includes("--force"),
    noCountTokens: argv.includes("--no-count-tokens"),
  };
}

export const cacheDir = () => path.join(WORK, "cache");
export const cachePath = (model, key) =>
  path.join(cacheDir(), `${PROMPT_VERSION}--${model}--${key.replace(":", "_")}.json`);

export function buildRequest(unit, opts, ctx) {
  return {
    custom_id: encodeCustomId(opts.model, unit.key),
    params: {
      model: opts.model,
      max_tokens: opts.maxTokens,
      system: ctx.system,
      output_config: {
        effort: opts.effort,
        format: { type: "json_schema", schema: ctx.schema },
      },
      messages: [{ role: "user", content: buildUserTurn(unit, ctx) }],
    },
  };
}

const roughTokens = (text) => Math.ceil(text.length / 3.6);

async function countTokensSample(requests, model) {
  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const client = new Anthropic();
  const sample = requests.slice(0, Math.min(5, requests.length));
  let total = 0;
  for (const r of sample) {
    const res = await client.messages.countTokens({
      model,
      system: r.params.system,
      messages: r.params.messages,
      output_config: r.params.output_config,
    });
    total += res.input_tokens;
  }
  return total / sample.length;
}

async function main(argv = process.argv.slice(2)) {
  const opts = parseArgs(argv);
  priceFor(opts.model); // fail fast on an unknown model
  if (!THINKING_TOKENS_BY_EFFORT[opts.effort]) {
    throw new Error(`--effort must be one of ${Object.keys(THINKING_TOKENS_BY_EFFORT).join(", ")}`);
  }

  const quran = loadQuran();
  const themeIndex = JSON.parse(fs.readFileSync(path.join(OUT, "themes-index.json"), "utf8"));
  const ctx = { quran, themeIndex, system: buildSystem(), schema: buildOutputSchema() };

  let units = selectUnits(opts.only);
  const total = units.length;

  let cached = 0;
  if (!opts.force) {
    units = units.filter((u) => {
      const hit = fs.existsSync(cachePath(opts.model, u.key));
      if (hit) cached++;
      return !hit;
    });
  }
  if (opts.limit) units = units.slice(0, opts.limit);

  const requests = units.map((u) => buildRequest(u, opts, ctx));

  // --- token accounting -----------------------------------------------------
  const systemText = ctx.system.map((b) => b.text).join("\n");
  const cachedSystemTokens = roughTokens(systemText) + roughTokens(JSON.stringify(ctx.schema));
  let perRequestInput = requests.length
    ? requests.reduce((n, r) => n + roughTokens(r.params.messages[0].content), 0) / requests.length
    : 0;
  let method = "character heuristic (~3.6 chars/token)";

  const haveCredential = Boolean(process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN);
  if (requests.length && haveCredential && !opts.noCountTokens) {
    try {
      const measured = await countTokensSample(requests, opts.model);
      perRequestInput = Math.max(0, measured - cachedSystemTokens);
      method = "measured via /v1/messages/count_tokens (5-request sample, free)";
    } catch (err) {
      method = `character heuristic (count_tokens unavailable: ${err.message})`;
    }
  }

  const outputTokens = ESTIMATED_JSON_OUTPUT_TOKENS + THINKING_TOKENS_BY_EFFORT[opts.effort];
  const est = estimateCost({
    model: opts.model,
    requests: requests.length,
    cachedSystemTokens,
    uncachedInputTokens: perRequestInput,
    outputTokens,
    batch: true,
  });

  console.log(`prompt version:    ${PROMPT_VERSION}`);
  console.log(`model:             ${opts.model}   effort: ${opts.effort}   max_tokens: ${opts.maxTokens}`);
  console.log(`selection:         --only ${opts.only}`);
  console.log(`units selected:    ${total}`);
  console.log(`  already cached:  ${cached}${opts.force ? " (ignored, --force)" : ""}`);
  if (opts.limit) console.log(`  --limit applied: ${opts.limit}`);
  console.log(`requests to send:  ${requests.length}`);
  console.log(`custom_id example: ${requests[0]?.custom_id ?? "-"}  (logical: ${requests[0] ? logicalCustomId(opts.model, units[0].key) : "-"})`);
  console.log("");
  console.log(`token counting:    ${method}`);
  console.log(`cached system:     ${cachedSystemTokens.toLocaleString()} tokens (written once, read per request)`);
  console.log(`per-request user:  ~${Math.round(perRequestInput).toLocaleString()} tokens`);
  console.log(`per-request out:   ~${outputTokens.toLocaleString()} tokens (${ESTIMATED_JSON_OUTPUT_TOKENS} JSON + ~${THINKING_TOKENS_BY_EFFORT[opts.effort]} thinking at effort=${opts.effort})`);
  console.log(`total input:       ~${Math.round(est.inputTokens).toLocaleString()} tokens`);
  console.log(`total output:      ~${Math.round(est.outputTokens).toLocaleString()} tokens`);
  console.log("");
  console.log(`estimated cost (Message Batches, 50% off, prompt caching on):`);
  console.log(`  cache write      ${usd(est.cacheWrite)}`);
  console.log(`  cache reads      ${usd(est.cacheRead)}`);
  console.log(`  input            ${usd(est.input)}`);
  console.log(`  output           ${usd(est.output)}`);
  console.log(`  TOTAL            ${usd(est.total)}`);
  console.log("");

  if (opts.dryRun) {
    console.log("--dry-run: nothing written, no API call made.");
    return { requests, est };
  }

  const name = opts.out ?? `${PROMPT_VERSION}-${opts.model}-${opts.only.replace(":", "")}`;
  const dir = path.join(WORK, "requests");
  fs.mkdirSync(dir, { recursive: true });
  fs.mkdirSync(cacheDir(), { recursive: true });
  const file = path.join(dir, `${name}.jsonl`);
  fs.writeFileSync(file, requests.map((r) => JSON.stringify(r)).join("\n") + "\n");
  fs.writeFileSync(
    path.join(dir, `${name}.meta.json`),
    JSON.stringify(
      { name, promptVersion: PROMPT_VERSION, model: opts.model, only: opts.only, effort: opts.effort,
        maxTokens: opts.maxTokens, requests: requests.length, estimatedCostUSD: Number(est.total.toFixed(2)),
        builtAt: new Date().toISOString() },
      null, 2,
    ) + "\n",
  );
  console.log(`wrote ${path.relative(process.cwd(), file)} (${requests.length} requests)`);
  console.log(`next: zsh -c 'source ~/.zshrc; node submit-batch.mjs ${name}'`);
  return { requests, est, file };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
export { main };
