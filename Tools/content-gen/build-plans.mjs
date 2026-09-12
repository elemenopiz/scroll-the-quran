#!/usr/bin/env node
// Builds Content/plans.json. The reading schedules that follow the mushaf (juz a day,
// Juz Amma) are computed from Content/quran/surahs.json and the Tanzil juz boundaries,
// so no range is typed by hand; the thematic plans are authored below.
//
//   node Tools/content-gen/build-plans.mjs
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const surahs = JSON.parse(await readFile(join(ROOT, "Content", "quran", "surahs.json"), "utf8"));
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

const juzStarts = [...xml.matchAll(/<juz\s+([^/>]+)\/>/g)].map((m) => {
    const a = Object.fromEntries([...m[1].matchAll(/(\w+)="([^"]*)"/g)].map((x) => [x[1], x[2]]));
    return { index: Number(a.index), surah: Number(a.sura), ayah: Number(a.aya) };
});

const globalIndex = (surah, ayah) => surahs[surah - 1].startIndex + ayah - 1;
const locate = (index) => {
    const surah = surahs.findLast((s) => s.startIndex <= index);
    return { surah: surah.number, ayah: index - surah.startIndex + 1 };
};

/// Splits a global ayah range into one `"surah:start-end"` ref per surah it crosses.
function refsFor(fromIndex, toIndex) {
    const refs = [];
    let cursor = fromIndex;
    while (cursor <= toIndex) {
        const at = locate(cursor);
        const surah = surahs[at.surah - 1];
        const lastInSurah = Math.min(toIndex, surah.startIndex + surah.ayahCount - 1);
        const end = lastInSurah - surah.startIndex + 1;
        refs.push(end === at.ayah ? `${at.surah}:${at.ayah}` : `${at.surah}:${at.ayah}-${end}`);
        cursor = lastInSurah + 1;
    }
    return refs;
}

const juzADay = juzStarts.map((juz, i) => {
    const from = globalIndex(juz.surah, juz.ayah);
    const to = i + 1 < juzStarts.length
        ? globalIndex(juzStarts[i + 1].surah, juzStarts[i + 1].ayah) - 1
        : 6235;
    return { day: juz.index, title: `Juz ${juz.index}`, refs: refsFor(from, to) };
});

// Juz Amma read one surah a day, from An-Naba to An-Nas.
const juzAmma = surahs.slice(77).map((surah, i) => ({
    day: i + 1,
    title: `${surah.name} — ${surah.meaning}`,
    refs: [surah.ayahCount === 1 ? `${surah.number}:1` : `${surah.number}:1-${surah.ayahCount}`],
}));

// Al-Kahf in four Friday sittings, on the surah's own narrative seams.
const alKahfFridays = [
    { day: 1, title: "The People of the Cave", refs: ["18:1-31"] },
    { day: 2, title: "The Two Gardens", refs: ["18:32-59"] },
    { day: 3, title: "Musa and al-Khidr", refs: ["18:60-82"] },
    { day: 4, title: "Dhul-Qarnayn and the Return", refs: ["18:83-110"] },
];

const protection = [
    { day: 1, title: "Ayat al-Kursi", refs: ["2:255"] },
    { day: 2, title: "The verses that follow it", refs: ["2:256-257"] },
    { day: 3, title: "The close of Al-Baqarah", refs: ["2:284-286"] },
    { day: 4, title: "Al-Ikhlas", refs: ["112:1-4"] },
    { day: 5, title: "Al-Falaq", refs: ["113:1-5"] },
    { day: 6, title: "An-Nas", refs: ["114:1-6"] },
    { day: 7, title: "All of them together", refs: ["2:255", "2:285-286", "112:1-4", "113:1-5", "114:1-6"] },
];

const patience = [
    { day: 1, title: "Seek help through patience", refs: ["2:153"] },
    { day: 2, title: "A test of fear and hunger", refs: ["2:155-157"] },
    { day: 3, title: "Hardship comes with ease", refs: ["94:1-8"] },
    { day: 4, title: "The patience of Yaqub", refs: ["12:83-87"] },
    { day: 5, title: "Ayyub calls on his Lord", refs: ["21:83-84"] },
    { day: 6, title: "Reward without measure", refs: ["39:10"] },
    { day: 7, title: "Patience and prayer together", refs: ["3:200"] },
];

const gratitude = [
    { day: 1, title: "If you are grateful", refs: ["14:7"] },
    { day: 2, title: "Remember Me and I will remember you", refs: ["2:152"] },
    { day: 3, title: "Countless favours", refs: ["16:18"] },
    { day: 4, title: "The gratitude of Sulayman", refs: ["27:19"] },
    { day: 5, title: "Eat of the good things", refs: ["2:172"] },
    { day: 6, title: "Few of My servants are grateful", refs: ["34:13"] },
    { day: 7, title: "Praise belongs to God", refs: ["1:1-7"] },
];

const mercy = [
    { day: 1, title: "My mercy encompasses all things", refs: ["7:156"] },
    { day: 2, title: "Do not despair of God's mercy", refs: ["39:53"] },
    { day: 3, title: "A mercy to the worlds", refs: ["21:107"] },
    { day: 4, title: "He prescribed mercy for Himself", refs: ["6:12"] },
    { day: 5, title: "Kindness to parents", refs: ["17:23-24"] },
    { day: 6, title: "The Most Gracious", refs: ["55:1-13"] },
    { day: 7, title: "Forgiveness before punishment", refs: ["15:49-50"] },
];

const plans = [
    {
        id: "juz-a-day",
        title: "The whole Quran in 30 days",
        subtitle: "One juz every day",
        image: "mushaf-page",
        startHere: true,
        section: "Read it through",
        bestFor: "Ramadan, or anyone who wants the whole book once",
        lengthDays: 30,
        dailyMinutes: 45,
        about: "The thirtieth of the Quran that Muslims call a juz has been the unit of daily reading for centuries. This plan walks the mushaf in order, one juz a day, from Al-Fatiha to An-Nas.",
        schedule: juzADay,
    },
    {
        id: "juz-amma",
        title: "Juz Amma",
        subtitle: "The last thirtieth, one surah a day",
        image: "lantern",
        startHere: true,
        section: "Recommended for beginners",
        bestFor: "Short sittings and the surahs you hear most in prayer",
        lengthDays: juzAmma.length,
        dailyMinutes: 8,
        about: "The final juz holds the short Meccan surahs most Muslims memorise first. One surah a day, from An-Naba to An-Nas.",
        schedule: juzAmma,
    },
    {
        id: "al-kahf-fridays",
        title: "Al-Kahf on Fridays",
        subtitle: "The Cave, in four sittings",
        image: "ink-wash",
        section: "Recommended for beginners",
        bestFor: "Keeping the Friday habit",
        lengthDays: 4,
        dailyMinutes: 15,
        about: "Reading Surah Al-Kahf on Friday is a long-standing practice. Its four narratives — the sleepers, the two gardens, Musa and al-Khidr, Dhul-Qarnayn — split naturally across four weeks.",
        schedule: alKahfFridays,
    },
    {
        id: "protection-verses",
        title: "Ayat al-Kursi and the close of Al-Baqarah",
        subtitle: "The verses recited for protection",
        image: "geometric-tile",
        section: "Recommended for beginners",
        bestFor: "Before sleep, and after prayer",
        lengthDays: 7,
        dailyMinutes: 6,
        about: "A week with the passages Muslims return to nightly: the Throne Verse, the two verses that follow it, the closing verses of Al-Baqarah, and the three surahs of refuge.",
        schedule: protection,
    },
    {
        id: "patience",
        title: "Patience",
        subtitle: "Sabr, a week at a time",
        image: "desert-dune",
        section: "Recommended for beginners",
        bestFor: "A hard stretch",
        lengthDays: 7,
        dailyMinutes: 10,
        about: "Sabr in the Quran is not passivity. It is holding steady while you keep acting — in loss, in fear, in waiting.",
        schedule: patience,
    },
    {
        id: "gratitude",
        title: "Gratitude",
        subtitle: "Shukr, a week at a time",
        image: "olive-branch",
        section: "By theme",
        bestFor: "Resetting how the day feels",
        lengthDays: 7,
        dailyMinutes: 10,
        about: "Shukr in the Quran is recognition that turns into action: noticing what was given, saying so, and using it well.",
        schedule: gratitude,
    },
    {
        id: "mercy",
        title: "Mercy",
        subtitle: "Rahmah, a week at a time",
        image: "dawn-light",
        section: "By theme",
        bestFor: "When you need the door open",
        lengthDays: 7,
        dailyMinutes: 10,
        about: "Rahmah is the attribute the Quran opens with and returns to most. This week follows it from God's mercy toward creation to the mercy asked of us.",
        schedule: mercy,
    },
];

// Sections carry their own copy and their own order: the beginner shelf is
// sequenced by how easy a plan is to start, not by the order the plans are
// defined in above. Every plan's `section` must name one of these titles, and
// every id listed here must exist — both are asserted below.
const sections = [
    {
        title: "Recommended for beginners",
        eyebrow: "For new readers",
        blurb: "Never opened the Quran before, or not sure where to start? Any of these works on its own — short, in order, and no prior reading needed.",
        planIDs: ["al-kahf-fridays", "patience", "juz-amma", "protection-verses"],
    },
    {
        title: "Read it through",
        eyebrow: "Start to finish",
        blurb: "The whole mushaf, in the order it is written, at the pace Muslims have read it for centuries.",
        planIDs: ["juz-a-day"],
    },
    {
        title: "By theme",
        eyebrow: "One idea at a time",
        blurb: "A week with a single theme, followed through the Quran verse by verse.",
        planIDs: ["gratitude", "mercy"],
    },
];

const planIDs = new Set(plans.map((p) => p.id));
const listed = new Set(sections.flatMap((s) => s.planIDs));
for (const s of sections) {
    for (const id of s.planIDs) {
        if (!planIDs.has(id)) throw new Error(`section "${s.title}" lists unknown plan "${id}"`);
    }
}
for (const p of plans) {
    if (!listed.has(p.id)) throw new Error(`plan "${p.id}" is in no section`);
    if (!sections.some((s) => s.title === p.section)) {
        throw new Error(`plan "${p.id}" names section "${p.section}", which does not exist`);
    }
}

const out = {
    version: 1,
    generatedBy: "Tools/content-gen/build-plans.mjs",
    sections,
    plans,
};

await writeFile(join(ROOT, "Content", "plans.json"), `${JSON.stringify(out, null, 2)}\n`);
console.log(`plans.json   ${plans.length} plans in ${sections.length} sections, ${plans.reduce((n, p) => n + p.schedule.length, 0)} scheduled days`);
