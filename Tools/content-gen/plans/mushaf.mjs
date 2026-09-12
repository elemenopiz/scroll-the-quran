// Mushaf arithmetic for the reading-plan generator: surah table, global ayah index,
// passage refs, the Tanzil juz/hizb boundaries, and the English word counts the
// `dailyMinutes` of every plan is computed from.
//
// Nothing here is hand-typed content. `Content/quran/surahs.json` supplies the ayah
// counts, `Content/quran/itani.json` the English word counts, and Tanzil's
// `quran-data.xml` the juz and hizb start points.
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

export const surahs = JSON.parse(
    await readFile(join(ROOT, "Content", "quran", "surahs.json"), "utf8"),
);

/// The Itani translation, one entry per ayah, indexed by global ayah index.
const itani = JSON.parse(await readFile(join(ROOT, "Content", "quran", "itani.json"), "utf8"));

export const AYAH_COUNT = surahs.at(-1).startIndex + surahs.at(-1).ayahCount;

// fetch-inputs.mjs caches the file under work/quran/; this script was written
// against work/. Both are gitignored, so accept either rather than fail on a
// layout difference no checkout can see.
const xmlCandidates = [
    join(ROOT, "Tools", "content-gen", "work", "quran", "quran-data.xml"),
    join(ROOT, "Tools", "content-gen", "work", "quran-data.xml"),
];
let xml = null;
for (const candidate of xmlCandidates) {
    try {
        xml = await readFile(candidate, "utf8");
        break;
    } catch { /* try the next location */ }
}
if (xml === null) {
    throw new Error(
        `No Tanzil quran-data.xml. Looked in:\n  ${xmlCandidates.join("\n  ")}\n` +
            "Run: node Tools/content-gen/fetch-inputs.mjs",
    );
}

const attrs = (tag) =>
    [...xml.matchAll(new RegExp(`<${tag}\\s+([^/>]+)/>`, "g"))].map((m) =>
        Object.fromEntries([...m[1].matchAll(/(\w+)="([^"]*)"/g)].map((x) => [x[1], x[2]])),
    );

/// The 30 juz start points, in order.
export const juzStarts = attrs("juz").map((a) => ({
    index: Number(a.index),
    surah: Number(a.sura),
    ayah: Number(a.aya),
}));

/// Tanzil publishes the 240 hizb quarters; a hizb starts on every fourth one, so the
/// 60 hizb boundaries are derived rather than typed. Two hizb make a juz, which is why
/// "half a juz a day" and "a hizb a day" are the same reading.
const quarters = attrs("quarter").map((a) => ({
    index: Number(a.index),
    surah: Number(a.sura),
    ayah: Number(a.aya),
}));
export const hizbStarts = quarters
    .filter((q) => (q.index - 1) % 4 === 0)
    .map((q, i) => ({ index: i + 1, surah: q.surah, ayah: q.ayah }));

export const surah = (number) => surahs[number - 1];

export const globalIndex = (surahNumber, ayah) => surah(surahNumber).startIndex + ayah - 1;

export const locate = (index) => {
    const found = surahs.findLast((s) => s.startIndex <= index);
    return { surah: found.number, ayah: index - found.startIndex + 1 };
};

/// Splits a global ayah range into one `"surah:start-end"` ref per surah it crosses.
export function refsFor(fromIndex, toIndex) {
    const refs = [];
    let cursor = fromIndex;
    while (cursor <= toIndex) {
        const at = locate(cursor);
        const s = surah(at.surah);
        const lastInSurah = Math.min(toIndex, s.startIndex + s.ayahCount - 1);
        const end = lastInSurah - s.startIndex + 1;
        refs.push(end === at.ayah ? `${at.surah}:${at.ayah}` : `${at.surah}:${at.ayah}-${end}`);
        cursor = lastInSurah + 1;
    }
    return refs;
}

/// `"67:1-30"` for a whole surah, `"108:1-3"` likewise; a one-ayah surah gets `"108:1"`.
export const wholeSurah = (number) => {
    const s = surah(number);
    return s.ayahCount === 1 ? `${number}:1` : `${number}:1-${s.ayahCount}`;
};

/// Turns a split of one surah into day objects. `cuts` are the last ayah of each sitting.
export function surahInSittings(number, cuts, titles) {
    const s = surah(number);
    const ends = [...cuts, s.ayahCount];
    let start = 1;
    return ends.map((end, i) => {
        const refs = [start === end ? `${number}:${start}` : `${number}:${start}-${end}`];
        start = end + 1;
        return { day: i + 1, title: titles[i], refs };
    });
}

const PARSE = /^(\d+):(\d+)(?:-(\d+))?$/;

/// `{ surah, start, end }` for a ref, or throws. The same grammar `PassageRef` parses.
export function parseRef(ref) {
    const m = PARSE.exec(ref);
    if (!m) throw new Error(`"${ref}" is not a passage ref`);
    const s = Number(m[1]);
    const start = Number(m[2]);
    const end = m[3] === undefined ? start : Number(m[3]);
    if (s < 1 || s > surahs.length) throw new Error(`"${ref}": no surah ${s}`);
    if (start < 1 || end < start) throw new Error(`"${ref}": empty or reversed range`);
    if (end > surah(s).ayahCount) {
        throw new Error(`"${ref}": ${surah(s).name} has ${surah(s).ayahCount} ayat`);
    }
    return { surah: s, start, end };
}

/// English words in a passage, from the Itani text. Whitespace-separated, which is how
/// every other word count in this pipeline is taken.
export function wordsIn(refs) {
    let words = 0;
    for (const ref of refs) {
        const { surah: s, start, end } = parseRef(ref);
        for (let ayah = start; ayah <= end; ayah += 1) {
            words += itani[globalIndex(s, ayah)].trim().split(/\s+/).filter(Boolean).length;
        }
    }
    return words;
}

/// The plan card's "about N min/day", computed from the schedule rather than typed:
/// the mean English word count of a day's reading at 150 words a minute, rounded to the
/// nearest five minutes, never below three. The floor is there because a two-line day
/// still costs the reader the walk to the app.
export function dailyMinutes(schedule) {
    const total = schedule.reduce((n, day) => n + wordsIn(day.refs), 0);
    const minutes = total / schedule.length / 150;
    return Math.max(3, Math.round(minutes / 5) * 5);
}
