#!/usr/bin/env node
// Builds Content/reflections.json from the catalogue in `reflections/`.
//
//   node Tools/content-gen/build-reflections.mjs
//   node Tools/content-gen/build-reflections.mjs --check   # verify only, write nothing
//
// Nothing in the output is hand-written JSON. The sayings, their attributions, their sources
// and their confidence live in `reflections/catalogue.mjs`; the editorial rules they follow
// are `docs/content/reflections.md`. This script is the place those rules are enforced.
//
// Only `confidence: "high"` entries reach `Content/reflections.json`. `medium` stays in the
// catalogue for the owner to check and promote, and is listed in the summary below.
//
// The script is deterministic: it reads only committed content, `generatedAt` is a fixed
// string rather than a clock reading, and running it twice leaves the output byte-identical.
import { writeFile, readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { reflections as authored, HADITH, EARLY, CLASSICAL } from "./reflections/catalogue.mjs";

const ROOT = join(fileURLToPath(new URL(".", import.meta.url)), "..", "..");
const OUTPUT = join(ROOT, "Content", "reflections.json");

/// The card's own line, not a name in a table: the Prophet is "one person" only in a sense
/// that would contradict the hadith floor below, so the per-person cap skips him.
const PROPHET = "The Prophet Muhammad (peace be upon him)";

export const RULES = {
    version: 1,
    /// Fixed, not `new Date()`: the build has to be reproducible from the tree alone.
    generatedAt: "2026-09-13T00:00:00.000Z",
    words: [10, 45],
    minShipped: 120,
    minHadith: 40,
    minEarly: 30,
    perPersonMax: 12,
    minPerTheme: 3,
    confidences: new Set(["high", "medium"]),
    classes: new Set([HADITH, EARLY, CLASSICAL]),
};

const ARABIC_SCRIPT = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/;
// The same guards `build-plans.mjs` applies to the only prose those cards carry.
const PRESCRIPTIVE = /\b(you must|you should|it is obligatory|you are required|forbidden|haram|thou shalt)\b/i;
const SECTARIAN = /\b(Sunni|Shia|Shi'a|Shiite|Salafi|Sufi|Hanafi|Maliki|Shafi'i|Hanbali|Wahhabi|Ash'ari|Maturidi|Mu'tazil\w*)\b/i;
const FOLK = /\b(attributed to|it is said that|some say|reportedly)\b/i;
const ID = /^[a-z0-9]+(-[a-z0-9]+)*$/;

const words = (text) => text.trim().split(/\s+/).filter(Boolean).length;

/** Collects every rule violation rather than throwing on the first. */
export function check(entries, themeIds) {
    const problems = [];
    const fail = (message) => problems.push(message);
    const seenIDs = new Set();
    const seenText = new Map();

    for (const entry of entries) {
        const id = entry.id ?? "<no id>";
        if (!ID.test(id)) fail(`${id}: id is not a lowercase slug`);
        if (seenIDs.has(id)) fail(`${id}: duplicate id`);
        seenIDs.add(id);

        if (!RULES.classes.has(entry.class)) fail(`${id}: unknown class "${entry.class}"`);
        if (!RULES.confidences.has(entry.confidence)) fail(`${id}: unknown confidence "${entry.confidence}"`);
        if (!entry.attribution?.trim()) fail(`${id}: no attribution`);
        if (entry.class === HADITH && entry.attribution !== PROPHET) {
            fail(`${id}: a hadith must be attributed "${PROPHET}"`);
        }
        if (entry.attribution !== PROPHET && /peace be upon him/i.test(entry.attribution)) {
            fail(`${id}: only the Prophet carries the honorific in the attribution line`);
        }
        if (!entry.source?.work?.trim()) fail(`${id}: no source work`);
        if (!entry.source?.locator?.toString().trim()) fail(`${id}: no source locator`);
        if (entry.source && "translator" in entry.source) {
            fail(`${id}: the catalogue does not set translator; the build writes "own"`);
        }

        const text = entry.text ?? "";
        const n = words(text);
        if (n < RULES.words[0] || n > RULES.words[1]) {
            fail(`${id}: text is ${n} words, must be ${RULES.words[0]}-${RULES.words[1]}`);
        }
        const normalised = text.toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
        if (seenText.has(normalised)) fail(`${id}: same rendering as ${seenText.get(normalised)}`);
        else seenText.set(normalised, id);

        if (ARABIC_SCRIPT.test(text)) fail(`${id}: text carries Arabic script; that is what "arabic" is for`);
        if (/\bAllah\b/.test(text)) fail(`${id}: text says "Allah"; English prose uses "God"`);
        if (PRESCRIPTIVE.test(text)) fail(`${id}: text reads as a ruling`);
        if (SECTARIAN.test(text)) fail(`${id}: text names a school or sect`);
        if (FOLK.test(text)) fail(`${id}: text hedges the attribution; a card cites a work or drops the entry`);
        if (/[!?]/.test(text.replace(/\?$/, ""))) {
            if (/!/.test(text)) fail(`${id}: text uses an exclamation mark`);
        }
        if (/\bMuhammad\b(?!\s*\(peace be upon him\))/.test(text)) {
            fail(`${id}: text names Muhammad without the honorific`);
        }

        if (entry.arabic !== undefined) {
            if (!ARABIC_SCRIPT.test(entry.arabic)) fail(`${id}: "arabic" is not Arabic script`);
            if (/[a-z]/i.test(entry.arabic)) fail(`${id}: "arabic" carries a transliteration`);
        }

        if (!Array.isArray(entry.themes) || entry.themes.length === 0) {
            fail(`${id}: no themes`);
        } else {
            for (const theme of entry.themes) {
                if (!themeIds.has(theme)) fail(`${id}: unknown theme "${theme}"`);
            }
            if (new Set(entry.themes).size !== entry.themes.length) fail(`${id}: repeats a theme`);
        }
    }

    return problems;
}

/** The per-class, per-person and per-theme quotas, measured over the entries that ship. */
export function quotas(shipped, themeIds) {
    const problems = [];
    const fail = (message) => problems.push(message);

    if (shipped.length < RULES.minShipped) {
        fail(`${shipped.length} entries ship at high confidence, at least ${RULES.minShipped} are needed`);
    }

    const byClass = new Map();
    for (const entry of shipped) byClass.set(entry.class, (byClass.get(entry.class) ?? 0) + 1);
    if ((byClass.get(HADITH) ?? 0) < RULES.minHadith) {
        fail(`${byClass.get(HADITH) ?? 0} hadith ship, at least ${RULES.minHadith} are needed`);
    }
    if ((byClass.get(EARLY) ?? 0) < RULES.minEarly) {
        fail(`${byClass.get(EARLY) ?? 0} entries from the Companions and early generations ship, at least ${RULES.minEarly} are needed`);
    }

    const byPerson = new Map();
    for (const entry of shipped) {
        if (entry.attribution === PROPHET) continue;
        byPerson.set(entry.attribution, (byPerson.get(entry.attribution) ?? 0) + 1);
    }
    for (const [person, n] of byPerson) {
        if (n > RULES.perPersonMax) fail(`${person} has ${n} entries, at most ${RULES.perPersonMax}`);
    }

    const byTheme = new Map([...themeIds].map((id) => [id, 0]));
    for (const entry of shipped) {
        for (const theme of entry.themes) byTheme.set(theme, (byTheme.get(theme) ?? 0) + 1);
    }
    for (const [theme, n] of byTheme) {
        if (n < RULES.minPerTheme) fail(`theme "${theme}" has ${n} entries, at least ${RULES.minPerTheme}`);
    }

    return { problems, byClass, byPerson, byTheme };
}

/** The on-disk row: the catalogue's editorial fields, plus the translator note. */
export const item = (entry) => ({
    id: entry.id,
    text: entry.text,
    attribution: entry.attribution,
    source: { work: entry.source.work, locator: String(entry.source.locator), translator: "own" },
    ...(entry.arabic ? { arabic: entry.arabic } : {}),
    themes: entry.themes,
    confidence: entry.confidence,
});

export async function build({ write = true } = {}) {
    const themeFile = JSON.parse(await readFile(join(ROOT, "Content", "themes.json"), "utf8"));
    const themeIds = new Set(themeFile.themes.map((t) => t.id));

    const problems = check(authored, themeIds);
    const shipped = authored.filter((entry) => entry.confidence === "high");
    const measured = quotas(shipped, themeIds);
    problems.push(...measured.problems);

    if (problems.length > 0) {
        console.error(`build-reflections: ${problems.length} problem(s)`);
        for (const problem of problems) console.error(`  ${problem}`);
        process.exit(1);
    }

    const out = {
        version: RULES.version,
        generatedBy: "Tools/content-gen/build-reflections.mjs",
        generatedAt: RULES.generatedAt,
        count: shipped.length,
        items: shipped.map(item),
    };
    if (write) await writeFile(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);

    const held = authored.filter((entry) => entry.confidence !== "high");
    console.log(
        `reflections.json   ${shipped.length} shipped of ${authored.length} authored ` +
        `(${held.length} held at medium)`,
    );
    for (const [name, n] of [...measured.byClass].sort((a, b) => b[1] - a[1])) {
        console.log(`  ${name}: ${n}`);
    }
    const top = [...measured.byPerson].sort((a, b) => b[1] - a[1]).slice(0, 5);
    console.log(`  per-person maximum: ${top.map(([p, n]) => `${p} ${n}`).join(", ")}`);
    const thin = [...measured.byTheme].filter(([, n]) => n <= RULES.minPerTheme).map(([t, n]) => `${t} ${n}`);
    console.log(`  thinnest themes: ${thin.length ? thin.join(", ") : "none at the floor"}`);
    if (held.length) console.log(`  held: ${held.map((e) => e.id).join(", ")}`);
    return out;
}

if (import.meta.url === `file://${process.argv[1]}`) {
    await build({ write: !process.argv.includes("--check") });
}
