#!/usr/bin/env node
// Submits a request file built by build-requests.mjs to the Message Batches API.
//
//   zsh -c 'source ~/.zshrc; node submit-batch.mjs p1-claude-opus-5-discover'
//
// Refuses to run without --confirm when the estimated cost exceeds --max-cost
// (default $15). Batch ids are appended to work/batches.json so poll-batch.mjs
// can pick them up in a later session.
import fs from "node:fs";
import path from "node:path";
import { WORK } from "./lib/data.mjs";

const MAX_REQUESTS_PER_BATCH = 10_000;

function args(argv) {
  const get = (f, d) => {
    const i = argv.indexOf(f);
    return i === -1 ? d : argv[i + 1];
  };
  const name = argv.find((a) => !a.startsWith("--") && argv[argv.indexOf(a) - 1] !== "--max-cost");
  return {
    name,
    maxCost: Number(get("--max-cost", 15)),
    confirm: argv.includes("--confirm"),
  };
}

export const batchesFile = () => path.join(WORK, "batches.json");

export function recordBatch(entry) {
  const f = batchesFile();
  const all = fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : [];
  all.push(entry);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, JSON.stringify(all, null, 2) + "\n");
  return f;
}

async function main(argv = process.argv.slice(2)) {
  const opts = args(argv);
  if (!opts.name) {
    console.error("usage: node submit-batch.mjs <request-name> [--max-cost 15] [--confirm]");
    process.exit(2);
  }
  const dir = path.join(WORK, "requests");
  const file = path.join(dir, `${opts.name}.jsonl`);
  const metaFile = path.join(dir, `${opts.name}.meta.json`);
  if (!fs.existsSync(file)) {
    console.error(`${file} not found. Run: node build-requests.mjs --only … --out ${opts.name}`);
    process.exit(1);
  }
  const meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, "utf8")) : {};
  const requests = fs
    .readFileSync(file, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((l) => JSON.parse(l));

  console.log(`request file:   ${path.relative(process.cwd(), file)}`);
  console.log(`requests:       ${requests.length}`);
  console.log(`model:          ${meta.model ?? requests[0].params.model}`);
  console.log(`estimated cost: $${(meta.estimatedCostUSD ?? NaN).toFixed?.(2) ?? "unknown"}`);

  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
    console.error("\nNo ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN in the environment.");
    console.error("Run inside: zsh -c 'source ~/.zshrc; node submit-batch.mjs …'");
    process.exit(1);
  }
  if (process.env.ANTHROPIC_BASE_URL && !/api\.anthropic\.com/.test(process.env.ANTHROPIC_BASE_URL)) {
    console.error(
      `\nANTHROPIC_BASE_URL is ${process.env.ANTHROPIC_BASE_URL}, which is not the Anthropic API.\n` +
        "The Message Batches API and claude-opus-5 are only available on api.anthropic.com.\n" +
        "Unset ANTHROPIC_BASE_URL (or point it at https://api.anthropic.com) and provide a real\n" +
        "Anthropic API key before submitting. Refusing to send Quran content elsewhere.",
    );
    process.exit(1);
  }
  const cost = meta.estimatedCostUSD ?? Infinity;
  if (cost > opts.maxCost && !opts.confirm) {
    console.error(
      `\nEstimated $${cost} exceeds --max-cost $${opts.maxCost}. Re-run with --confirm to proceed.`,
    );
    process.exit(1);
  }

  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const client = new Anthropic();

  const chunks = [];
  for (let i = 0; i < requests.length; i += MAX_REQUESTS_PER_BATCH) {
    chunks.push(requests.slice(i, i + MAX_REQUESTS_PER_BATCH));
  }

  for (const [i, chunk] of chunks.entries()) {
    const batch = await client.messages.batches.create({ requests: chunk });
    const entry = {
      id: batch.id,
      name: opts.name,
      chunk: `${i + 1}/${chunks.length}`,
      requests: chunk.length,
      model: meta.model ?? chunk[0].params.model,
      promptVersion: meta.promptVersion ?? "p1",
      processingStatus: batch.processing_status,
      createdAt: batch.created_at,
      submittedAt: new Date().toISOString(),
    };
    recordBatch(entry);
    console.log(`\nBATCH ID: ${batch.id}   (${chunk.length} requests, ${entry.chunk})`);
    console.log(`status:   ${batch.processing_status}`);
  }
  console.log(`\nrecorded in ${path.relative(process.cwd(), batchesFile())}`);
  console.log(`poll with: zsh -c 'source ~/.zshrc; node poll-batch.mjs --all'`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
export { main };
