#!/usr/bin/env node
// Authoring mode — write Deep Study notes without the Batch API.
//
// There is no Anthropic credential for this project, so an Opus agent running
// in a Claude Code session is the model. This tool hands that agent the exact
// prompt the batch pipeline would have sent, validates what it writes, and
// stores it in `work/cache/` in the same shape poll-batch.mjs produces, so
// assemble.mjs and validate.mjs stay the source of truth.
//
//   node author.mjs todo --only discover --limit 40
//   node author.mjs prompt 2:255
//   node author.mjs write 2:255 body.json
//   node author.mjs write-dir bodies/
//   node author.mjs assemble
//   node author.mjs status
//
// The simplify pass (docs/tasks/content-simplify.md) rewrites units that already
// exist so they read at grade 8.5 or below and gain an `explainEasier` line:
//
//   node author.mjs rewrite-todo --only discover --limit 55
//   node author.mjs rewrite 2:255
//   node author.mjs rewrite-dir bodies/
//
// An author never edits out/study/*.json by hand: write -> assemble -> validate.
import fs from "node:fs";
import path from "node:path";
import { OUT, loadQuran } from "./lib/data.mjs";
import { discoverKeys } from "./lib/units.mjs";
import { PROMPT_VERSION } from "./lib/prompt.mjs";
import {
  AUTHOR_MODEL, DEFAULT_AUTHOR, SIMPLIFY_VERSION, ensureUnits, todoUnits, promptFor,
  validateBodies, normaliseBody, writeRecord, statusReport, assembledKeys,
  rewriteTodoUnits, rewritePromptFor, checkRewriteFidelity, simplifiedKeys,
} from "./lib/author.mjs";
import { main as assembleMain } from "./assemble.mjs";

const USAGE = `usage: node author.mjs <command> [options]

  todo [--only discover|all|surah:N|keys:a,b] [--limit N] [--json]
        Unit keys with no work/cache record and no entry in the committed
        out/study shards, with ayah and word counts.

  prompt <key> [--no-system]
        The exact system prompt (prompts/system.md + theme list) followed by
        the rendered user turn for that unit.

  write <key> <body.json> [--author NAME] [--model NAME] [--force]
        Validate an authored body against the full validate.mjs rule set and,
        if clean, write work/cache/${PROMPT_VERSION}--<model>--<key>.json.

  write-dir <dir> [--author NAME] [--model NAME] [--force]
        The same for a directory of <key>.json bodies (":" or "_" in the
        filename). All-or-nothing: nothing is written if any body fails.

  assemble [--only discover|all|surah:N] [--model NAME]
        assemble.mjs, plus a per-surah count table and the Discover gaps.

  status [--model NAME]
        Units total / cached / assembled / Discover remaining, per surah.

  rewrite-todo [--only discover|all|surah:N|keys:a,b] [--limit N] [--json]
        Units that exist today and have not been through the simplify pass,
        with the grade of their worst section and which sections are over.

  rewrite <key>
        prompts/simplify.md, the passage, what the unit measures today and the
        current body — the whole turn a rewrite agent works from.

  rewrite-dir <dir> [--author NAME] [--model NAME]
        Validate a directory of rewritten <key>.json bodies against the full
        rule set plus the readability targets, check nothing that must stay
        verbatim moved, and cache them with meta.simplified set. All-or-nothing.
`;

/** Flags that take a value; everything else beginning with "--" is a switch. */
const VALUE_FLAGS = new Set(["--only", "--limit", "--model", "--author"]);

const arg = (argv, flag, fallback = null) => {
  const i = argv.indexOf(flag);
  return i === -1 ? fallback : argv[i + 1];
};

/** Positional arguments, with value-flag operands removed. */
const positionals = (argv) => {
  const out = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) {
      if (VALUE_FLAGS.has(argv[i])) i++;
      continue;
    }
    out.push(argv[i]);
  }
  return out;
};

const fail = (msg) => {
  console.error(msg);
  process.exit(1);
};

const keyFromFilename = (f) => path.basename(f, ".json").replace("_", ":");

const report = (res) => {
  for (const w of res.warnings) console.log(`WARN  ${w}`);
  for (const e of res.errors) console.log(`ERROR ${e}`);
};

// --- commands ----------------------------------------------------------------

function cmdTodo(argv) {
  const only = arg(argv, "--only", "discover");
  const limitRaw = arg(argv, "--limit");
  const units = todoUnits({
    only,
    limit: limitRaw ? Number(limitRaw) : null,
    model: arg(argv, "--model", null),
  });
  if (argv.includes("--json")) {
    console.log(JSON.stringify(units, null, 2));
    return;
  }
  for (const u of units) {
    console.log(
      `${u.key.padEnd(12)} ${String(u.ayatCount).padStart(2)} ayat  ` +
        `${String(u.words).padStart(3)} words  ${u.tier}`,
    );
  }
  console.log(`\n${units.length} unit(s) to author (--only ${only}).`);
}

function cmdPrompt(argv) {
  const key = positionals(argv)[0];
  if (!key) fail("usage: node author.mjs prompt <key> [--no-system]");
  const { system, user } = promptFor(key);
  if (!argv.includes("--no-system")) {
    console.log("========== SYSTEM ==========\n");
    console.log(system.trimEnd());
    console.log("\n========== USER ==========\n");
  }
  console.log(user.trimEnd());
}

function writeBodies(entries, argv) {
  const model = arg(argv, "--model", AUTHOR_MODEL);
  const author = arg(argv, "--author", DEFAULT_AUTHOR);
  const done = argv.includes("--force") ? new Set() : assembledKeys();
  const clash = entries.filter((e) => done.has(e.key));
  if (clash.length) {
    fail(
      `already assembled in out/study (pass --force to rewrite): ${clash.map((e) => e.key).join(", ")}`,
    );
  }

  const results = validateBodies(entries, { model });
  let bad = 0;
  for (const { key } of entries) {
    const res = results.get(key) ?? { errors: [], warnings: [] };
    if (res.errors.length || res.warnings.length) report(res);
    if (res.errors.length) bad++;
  }
  if (bad) {
    console.error(`\n${bad} of ${entries.length} body/bodies rejected. Nothing written.`);
    process.exit(1);
  }

  for (const { key, body } of entries) {
    const { body: clean } = normaliseBody(body, key);
    const { file } = writeRecord(key, clean, { author, model });
    console.log(`wrote ${path.relative(process.cwd(), file)}`);
  }
  console.log(`\n${entries.length} record(s) cached. Next: node author.mjs assemble`);
}

function cmdWrite(argv) {
  const [key, file] = positionals(argv);
  if (!key || !file) fail("usage: node author.mjs write <key> <body.json> [--author NAME]");
  if (!fs.existsSync(file)) fail(`no such file: ${file}`);
  let body;
  try {
    body = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    fail(`${file}: not valid JSON (${e.message})`);
  }
  writeBodies([{ key, body }], argv);
}

function cmdWriteDir(argv) {
  const dir = positionals(argv)[0];
  if (!dir) fail("usage: node author.mjs write-dir <dir> [--author NAME]");
  if (!fs.existsSync(dir)) fail(`no such directory: ${dir}`);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort();
  if (!files.length) fail(`${dir}: no .json bodies found`);
  const entries = [];
  for (const f of files) {
    try {
      entries.push({ key: keyFromFilename(f), body: JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")) });
    } catch (e) {
      fail(`${f}: not valid JSON (${e.message})`);
    }
  }
  console.log(`${entries.length} body/bodies from ${dir}`);
  writeBodies(entries, argv);
}

function cmdAssemble(argv) {
  ensureUnits();
  const passthrough = [];
  for (const flag of ["--only", "--model"]) {
    const v = arg(argv, flag);
    if (v) passthrough.push(flag, v);
  }
  assembleMain(passthrough);

  const dir = path.join(OUT, "study");
  const shards = fs.existsSync(dir)
    ? fs.readdirSync(dir).filter((f) => /^surah_\d{3}\.json$/.test(f)).sort()
    : [];
  const quran = loadQuran();
  console.log(`\nper-surah counts (${shards.length} shard(s)):`);
  let total = 0;
  for (const f of shards) {
    const shard = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
    const n = shard.studies?.length ?? 0;
    total += n;
    console.log(`  ${f}  ${String(n).padStart(3)}  ${quran.byNumber.get(shard.surah).name}`);
  }
  console.log(`  ${"total".padEnd(16)} ${String(total).padStart(3)}`);

  const assembled = assembledKeys();
  const gaps = discoverKeys().filter((k) => !assembled.has(k));
  console.log(`\ndiscover gaps: ${gaps.length} of ${discoverKeys().length}`);
  for (let i = 0; i < gaps.length; i += 12) console.log(`  ${gaps.slice(i, i + 12).join(" ")}`);
}

function cmdStatus(argv) {
  const s = statusReport({ model: arg(argv, "--model", null) });
  console.log(`prompt version:      ${PROMPT_VERSION}`);
  console.log(`units total:         ${s.units}`);
  console.log(`cached (work/cache): ${s.cached}`);
  console.log(`assembled (out/study): ${s.assembled}`);
  console.log(`discover units:      ${s.discover}`);
  console.log(`  assembled:         ${s.discoverAssembled}`);
  console.log(`  cached only:       ${s.discoverCachedOnly}`);
  console.log(`  remaining:         ${s.discoverRemaining.length}`);
  if (s.surahs.length) {
    console.log(`\nsurah  units  cached  assembled  discover`);
    for (const r of s.surahs) {
      console.log(
        `${String(r.surah).padStart(5)}  ${String(r.units).padStart(5)}  ` +
          `${String(r.cached).padStart(6)}  ${String(r.assembled).padStart(9)}  ` +
          `${String(r.discover).padStart(8)}`,
      );
    }
  }
}

// --- the simplify pass -------------------------------------------------------

function cmdRewriteTodo(argv) {
  const only = arg(argv, "--only", "discover");
  const limitRaw = arg(argv, "--limit");
  const units = rewriteTodoUnits({
    only,
    limit: limitRaw ? Number(limitRaw) : null,
    model: arg(argv, "--model", null),
  });
  if (argv.includes("--json")) {
    console.log(JSON.stringify(units, null, 2));
    return;
  }
  for (const u of units) {
    console.log(
      `${u.key.padEnd(12)} worst grade ${String(u.worstGrade).padStart(5)}  ` +
        `${u.tier.padEnd(8)} ${u.over.length} over: ${u.over.join(", ") || "-"}`,
    );
  }
  console.log(`\n${units.length} unit(s) to rewrite (--only ${only}).`);
  console.log(`${simplifiedKeys().size} unit(s) already simplified.`);
}

function cmdRewrite(argv) {
  const key = positionals(argv)[0];
  if (!key) fail("usage: node author.mjs rewrite <key>");
  console.log(rewritePromptFor(key, { model: arg(argv, "--model", null) }).text);
}

function cmdRewriteDir(argv) {
  const dir = positionals(argv)[0];
  if (!dir) fail("usage: node author.mjs rewrite-dir <dir> [--author NAME]");
  if (!fs.existsSync(dir)) fail(`no such directory: ${dir}`);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort();
  if (!files.length) fail(`${dir}: no .json bodies found`);

  const entries = [];
  for (const f of files) {
    try {
      entries.push({
        key: keyFromFilename(f),
        body: JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")),
      });
    } catch (e) {
      fail(`${f}: not valid JSON (${e.message})`);
    }
  }
  console.log(`${entries.length} rewritten body/bodies from ${dir}`);

  const model = arg(argv, "--model", AUTHOR_MODEL);
  const author = arg(argv, "--author", DEFAULT_AUTHOR);

  // Two passes, both reported before anything is written: what must not have
  // moved since the previous version, then the full rule set with the
  // readability targets as errors (that is what `simplified` buys).
  const results = validateBodies(entries, { model, simplified: SIMPLIFY_VERSION, author });
  let bad = 0;
  for (const { key, body } of entries) {
    const res = results.get(key) ?? { errors: [], warnings: [] };
    const fidelity = checkRewriteFidelity(key, body, { model });
    const errors = [...fidelity.errors, ...res.errors];
    const warnings = [...fidelity.warnings, ...res.warnings];
    if (errors.length || warnings.length) report({ errors, warnings });
    if (errors.length) bad++;
  }
  if (bad) {
    console.error(`\n${bad} of ${entries.length} rewrite(s) rejected. Nothing written.`);
    process.exit(1);
  }

  for (const { key, body } of entries) {
    const { body: clean } = normaliseBody(body, key);
    const { file } = writeRecord(key, clean, { author, model, simplified: SIMPLIFY_VERSION });
    console.log(`wrote ${path.relative(process.cwd(), file)}`);
  }
  console.log(`\n${entries.length} rewrite(s) cached. Next: node author.mjs assemble`);
}

const COMMANDS = {
  todo: cmdTodo,
  prompt: cmdPrompt,
  write: cmdWrite,
  "write-dir": cmdWriteDir,
  assemble: cmdAssemble,
  status: cmdStatus,
  "rewrite-todo": cmdRewriteTodo,
  rewrite: cmdRewrite,
  "rewrite-dir": cmdRewriteDir,
};

function main(argv = process.argv.slice(2)) {
  const cmd = argv[0];
  if (!cmd || cmd === "--help" || cmd === "-h" || !COMMANDS[cmd]) {
    console.log(USAGE);
    process.exit(cmd && cmd !== "--help" && cmd !== "-h" ? 2 : 0);
  }
  COMMANDS[cmd](argv.slice(1));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    main();
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}
export { main };
