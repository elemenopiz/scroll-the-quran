// Prompt assembly: the cached system blocks and the per-unit user turn.
import fs from "node:fs";
import path from "node:path";
import { ROOT, OUT, loadQuran, parseKey, words } from "./data.mjs";

export const PROMPT_VERSION = "p1";

const read = (p) => fs.readFileSync(p, "utf8");

/** Minimal {{var}} / {{#if var}}…{{/if}} / {{! comment }} renderer. */
export function render(template, vars) {
  let out = template.replace(/\{\{!--[\s\S]*?--\}\}\n?/g, "");
  out = out.replace(/\{\{#if (\w+)\}\}\n?([\s\S]*?)\{\{\/if\}\}\n?/g, (_, name, body) =>
    vars[name] ? body : "",
  );
  out = out.replace(/\{\{(\w+)\}\}/g, (_, name) => (vars[name] ?? "").toString());
  return out.replace(/\n{3,}/g, "\n\n").trim() + "\n";
}

/**
 * The system prompt is byte-identical for every request in a run, so both
 * blocks sit before any per-unit content and the second carries the cache
 * breakpoint. See shared/prompt-caching.md: render order is tools → system →
 * messages, and any byte change invalidates everything after it.
 */
export function buildSystem() {
  const rules = read(path.join(ROOT, "prompts", "system.md"));
  const { themes } = JSON.parse(read(path.join(OUT, "themes.json")));
  const list = themes.map((t) => `- ${t.id} — ${t.title}: ${t.blurb}`).join("\n");
  return [
    { type: "text", text: rules },
    {
      type: "text",
      text: `# Theme list\n\nChoose exactly one theme for each passage. Use the id verbatim as \`themeId\` and the title verbatim as \`theme\`.\n\n${list}\n`,
      cache_control: { type: "ephemeral" },
    },
  ];
}

const CONTEXT_AYAT = 3;

export function buildUserTurn(unit, { quran = loadQuran(), themeIndex = null, tafsir = null } = {}) {
  const template = read(path.join(ROOT, "prompts", "user.hbs"));
  const s = quran.byNumber.get(unit.surah);
  const lines = (from, to) => {
    const out = [];
    for (let a = from; a <= to; a++) out.push(`${a}. ${quran.english(unit.surah, a)}`);
    return out.join("\n");
  };

  const beforeFrom = Math.max(1, unit.start - CONTEXT_AYAT);
  const afterTo = Math.min(s.ayahCount, unit.end + CONTEXT_AYAT);

  const arabic = [];
  for (let a = unit.start; a <= unit.end; a++) arabic.push(quran.uthmani(unit.surah, a));

  let themeHint = null;
  if (themeIndex) {
    const ids = new Set();
    for (let a = unit.start; a <= unit.end; a++) {
      for (const id of themeIndex[`${unit.surah}:${a}`] ?? []) ids.add(id);
    }
    if (ids.size) themeHint = [...ids].join(", ");
  }

  const ayatInUnit = unit.end - unit.start + 1;
  return render(template, {
    key: unit.key,
    surahNumber: s.number,
    surahName: s.name,
    surahMeaning: s.meaning,
    revelationPlace: s.revelation === "makki" ? "Mecca" : "Medina",
    ayahCount: s.ayahCount,
    juz: (s.juz ?? []).join(", "),
    ayatInUnit,
    ayatWord: ayatInUnit === 1 ? "ayah" : "ayat",
    tier: unit.tier ?? "standard",
    arabic: arabic.join("\n"),
    english: lines(unit.start, unit.end),
    contextBefore: beforeFrom < unit.start ? lines(beforeFrom, unit.start - 1) : "",
    contextBeforeRange: `${unit.surah}:${beforeFrom}-${unit.start - 1}`,
    contextAfter: afterTo > unit.end ? lines(unit.end + 1, afterTo) : "",
    contextAfterRange: `${unit.surah}:${unit.end + 1}-${afterTo}`,
    themeHint,
    tafsir,
  });
}

/**
 * Structured-output schema: the model only fills the interpretive fields.
 * key/surah/start/end/tier/meta are stamped by assemble.mjs from the unit
 * record, so they are not asked for here. Validation-only keywords
 * (minLength/pattern/x-*) are stripped — output_config.format accepts a
 * conservative JSON Schema subset.
 */
export function buildOutputSchema() {
  const full = JSON.parse(read(path.join(ROOT, "schema", "study.schema.json")));
  const strip = (node) => {
    if (Array.isArray(node)) return node.map(strip);
    if (!node || typeof node !== "object") return node;
    const out = {};
    for (const [k, v] of Object.entries(node)) {
      if (["minLength", "maxLength", "pattern", "format", "$comment", "$id", "$schema"].includes(k)) continue;
      if (k.startsWith("x-")) continue;
      out[k] = strip(v);
    }
    return out;
  };
  const fields = full["x-modelFields"];
  const properties = {};
  for (const f of fields) properties[f] = strip(full.properties[f]);
  return {
    type: "object",
    additionalProperties: false,
    required: fields,
    properties,
  };
}

/** Logical id per the brief: `p1:<model>:<key>`. */
export const logicalCustomId = (model, key) => `${PROMPT_VERSION}:${model}:${key}`;

/**
 * Wire form. The Batches API restricts custom_id to [a-zA-Z0-9_-]{1,64}, so
 * the two separators become `--` and the key's colon becomes `_`.
 * `p1:claude-opus-5:2:255-257` -> `p1--claude-opus-5--2_255-257`.
 */
export const encodeCustomId = (model, key) =>
  `${PROMPT_VERSION}--${model}--${key.replace(":", "_")}`;

export function decodeCustomId(id) {
  const parts = id.split("--");
  if (parts.length !== 3) return null;
  return { promptVersion: parts[0], model: parts[1], key: parts[2].replace("_", ":") };
}

export { words, parseKey };
