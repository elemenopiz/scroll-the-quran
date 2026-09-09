#!/usr/bin/env node
// Polls Message Batches and writes each successful result into work/cache/.
//
//   zsh -c 'source ~/.zshrc; node poll-batch.mjs --all'          # poll once
//   zsh -c 'source ~/.zshrc; node poll-batch.mjs --all --watch'  # until ended
//   zsh -c 'source ~/.zshrc; node poll-batch.mjs msgbatch_123'
//
// Results arrive in any order and are keyed by custom_id, never by position.
import fs from "node:fs";
import path from "node:path";
import { WORK } from "./lib/data.mjs";
import { decodeCustomId } from "./lib/prompt.mjs";
import { cachePath, cacheDir } from "./build-requests.mjs";
import { batchesFile } from "./submit-batch.mjs";

const POLL_INTERVAL_MS = 60_000;

function loadRecorded() {
  const f = batchesFile();
  return fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : [];
}

function saveRecorded(all) {
  fs.writeFileSync(batchesFile(), JSON.stringify(all, null, 2) + "\n");
}

/** Extract the JSON study body from a successful batch result message. */
export function parseResultMessage(message) {
  const text = message.content.find((b) => b.type === "text")?.text;
  if (!text) throw new Error("no text block in message");
  return JSON.parse(text);
}

async function drain(client, batchId, model) {
  fs.mkdirSync(cacheDir(), { recursive: true });
  const counts = { succeeded: 0, errored: 0, expired: 0, canceled: 0, unparseable: 0 };
  const failures = [];
  for await (const result of await client.messages.batches.results(batchId)) {
    const decoded = decodeCustomId(result.custom_id);
    if (!decoded) {
      counts.unparseable++;
      continue;
    }
    switch (result.result.type) {
      case "succeeded": {
        try {
          const body = parseResultMessage(result.result.message);
          const usage = result.result.message.usage;
          fs.writeFileSync(
            cachePath(decoded.model ?? model, decoded.key),
            JSON.stringify(
              { key: decoded.key, promptVersion: decoded.promptVersion, model: decoded.model,
                batchId, usage, body, receivedAt: new Date().toISOString() },
              null, 2,
            ) + "\n",
          );
          counts.succeeded++;
        } catch (e) {
          counts.unparseable++;
          failures.push(`${result.custom_id}: unparseable JSON (${e.message})`);
        }
        break;
      }
      case "errored":
        counts.errored++;
        failures.push(`${result.custom_id}: ${result.result.error?.type ?? "error"}`);
        break;
      case "expired":
        counts.expired++;
        failures.push(`${result.custom_id}: expired`);
        break;
      case "canceled":
        counts.canceled++;
        break;
    }
  }
  return { counts, failures };
}

async function main(argv = process.argv.slice(2)) {
  const watch = argv.includes("--watch");
  const explicit = argv.filter((a) => a.startsWith("msgbatch_"));
  const recorded = loadRecorded();
  const ids = explicit.length
    ? explicit
    : argv.includes("--all")
      ? recorded.map((b) => b.id)
      : [];
  if (!ids.length) {
    console.error("usage: node poll-batch.mjs (--all | msgbatch_…) [--watch]");
    if (recorded.length) {
      console.error("\nrecorded batches:");
      for (const b of recorded) console.error(`  ${b.id}  ${b.name} ${b.chunk} ${b.processingStatus}`);
    }
    process.exit(2);
  }

  const { default: Anthropic } = await import("@anthropic-ai/sdk");
  const client = new Anthropic();

  const pending = new Set(ids);
  while (pending.size) {
    for (const id of [...pending]) {
      const batch = await client.messages.batches.retrieve(id);
      const c = batch.request_counts;
      console.log(
        `${new Date().toISOString()}  ${id}  ${batch.processing_status}  ` +
          `processing=${c.processing} succeeded=${c.succeeded} errored=${c.errored} expired=${c.expired}`,
      );
      const entry = recorded.find((b) => b.id === id);
      if (entry) {
        entry.processingStatus = batch.processing_status;
        entry.requestCounts = c;
      }
      if (batch.processing_status === "ended") {
        const { counts, failures } = await drain(client, id, entry?.model);
        console.log(`  drained -> work/cache/: ${JSON.stringify(counts)}`);
        for (const f of failures.slice(0, 20)) console.log(`    ! ${f}`);
        if (failures.length > 20) console.log(`    … ${failures.length - 20} more`);
        if (entry) entry.drainedAt = new Date().toISOString();
        pending.delete(id);
      }
    }
    if (recorded.length) saveRecorded(recorded);
    if (!pending.size) break;
    if (!watch) {
      console.log("\nstill processing. Re-run later, or add --watch to block.");
      return;
    }
    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
  console.log("\nall batches ended. Next: node validate.mjs work/cache && node assemble.mjs");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
export { main, drain };
