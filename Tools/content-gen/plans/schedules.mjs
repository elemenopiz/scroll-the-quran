// Every plan's day-by-day schedule.
//
// Schedules that follow the mushaf's own divisions (a juz a day, a hizb a day, Juz Amma,
// the last forty surahs by length) are computed from `Content/quran/surahs.json` and the
// Tanzil juz/hizb boundaries, so no range in them is typed by hand. The rest are authored
// here, at whole-ayah seams: `build-plans.mjs` re-parses every ref against the surah table
// and refuses to write a file with a bad one.
import {
    AYAH_COUNT,
    globalIndex,
    hizbStarts,
    juzStarts,
    refsFor,
    surah,
    surahInSittings,
    surahs,
    wholeSurah,
} from "./mushaf.mjs";

/// The global ayah range a numbered division covers, given the list of its start points.
function spans(starts) {
    return starts.map((start, i) => {
        const from = globalIndex(start.surah, start.ayah);
        const to = i + 1 < starts.length
            ? globalIndex(starts[i + 1].surah, starts[i + 1].ayah) - 1
            : AYAH_COUNT - 1;
        return { index: start.index, refs: refsFor(from, to) };
    });
}

const juzSpans = spans(juzStarts);
const hizbSpans = spans(hizbStarts);

// ── Read it through ────────────────────────────────────────────────────────────

export const juzADay = juzSpans.map((span) => ({
    day: span.index,
    title: `Juz ${span.index}`,
    refs: span.refs,
}));

export const khatm60 = hizbSpans.map((span) => ({
    day: span.index,
    title: `Hizb ${span.index}`,
    refs: span.refs,
}));

/// The Ramadan reading is the same thirty portions, counted by night rather than by day,
/// because that is when the month's congregational reading happens.
export const ramadanKhatm = juzSpans.map((span) => ({
    day: span.index,
    title: `Night ${span.index} · Juz ${span.index}`,
    refs: span.refs,
}));

// ── Start here ─────────────────────────────────────────────────────────────────

// Juz Amma read one surah a day, from An-Naba to An-Nas.
export const juzAmma = surahs.slice(77).map((s, i) => ({
    day: i + 1,
    title: `${s.name} — ${s.meaning}`,
    refs: [wholeSurah(s.number)],
}));

export const firstWeek = [
    { day: 1, title: "The opening", refs: ["1:1-7"] },
    { day: 2, title: "The Throne Verse", refs: ["2:255"] },
    { day: 3, title: "The close of Al-Baqarah", refs: ["2:285-286"] },
    { day: 4, title: "God, in four lines", refs: ["112:1-4"] },
    { day: 5, title: "The two surahs of refuge", refs: ["113:1-5", "114:1-6"] },
    { day: 6, title: "Time, and what survives it", refs: ["103:1-3"] },
    { day: 7, title: "Abundance", refs: ["108:1-3"] },
];

// Al-Kahf in four Friday sittings, on the surah's own narrative seams.
export const alKahfFridays = surahInSittings(18, [31, 59, 82], [
    "The People of the Cave",
    "The Two Gardens",
    "Musa and al-Khidr",
    "Dhul-Qarnayn and the Return",
]);

export const protection = [
    { day: 1, title: "Ayat al-Kursi", refs: ["2:255"] },
    { day: 2, title: "The verses that follow it", refs: ["2:256-257"] },
    { day: 3, title: "The close of Al-Baqarah", refs: ["2:284-286"] },
    { day: 4, title: "Al-Ikhlas", refs: ["112:1-4"] },
    { day: 5, title: "Al-Falaq", refs: ["113:1-5"] },
    { day: 6, title: "An-Nas", refs: ["114:1-6"] },
    { day: 7, title: "All of them together", refs: ["2:255", "2:285-286", "112:1-4", "113:1-5", "114:1-6"] },
];

// ── The Sunnah of reading ──────────────────────────────────────────────────────

/// Al-Mulk three ayat at a time. Its thirty ayat divide exactly into ten sittings.
export const mulkEveryNight = (() => {
    // One title per sitting, taken from the line that sitting turns on: ayat 1-3, 4-6,
    // 7-9 and so on down the surah.
    const titles = [
        "Blessed is the One in whose hand is dominion",
        "Look again, and look again",
        "Did no warner come to you?",
        "For those who fear their Lord unseen",
        "He made the earth manageable",
        "Are you secure from the One above?",
        "Who could be an army for you?",
        "Walking face down, or walking upright",
        "Only God knows when",
        "If your water went into the ground",
    ];
    return Array.from({ length: 10 }, (_, i) => ({
        day: i + 1,
        title: titles[i],
        refs: [`67:${i * 3 + 1}-${i * 3 + 3}`],
    }));
})();

export const baqarahNights = [
    { day: 1, title: "The messenger believes, and so do they", refs: ["2:285"] },
    { day: 2, title: "We hear, and we obey", refs: ["2:285"] },
    { day: 3, title: "God burdens no soul beyond its capacity", refs: ["2:286"] },
    { day: 4, title: "Do not take us to task if we forget", refs: ["2:286"] },
    { day: 5, title: "The two together, as they are read at night", refs: ["2:285-286"] },
    { day: 6, title: "What comes just before them", refs: ["2:284"] },
    { day: 7, title: "The close of the surah, whole", refs: ["2:284-286"] },
];

const quls = ["112:1-4", "113:1-5", "114:1-6"];
export const threeQuls = [
    { day: 1, title: "All three, morning and evening", refs: quls },
    { day: 2, title: "The One, with no equal", refs: ["112:1-4"] },
    { day: 3, title: "Refuge from what the night brings", refs: ["113:1-5"] },
    { day: 4, title: "Refuge from what whispers", refs: ["114:1-6"] },
    { day: 5, title: "The two that ask for shelter", refs: ["113:1-5", "114:1-6"] },
    { day: 6, title: "All three, three times over", refs: quls },
    { day: 7, title: "Morning, evening, and again tomorrow", refs: quls },
];

// ── Stories of the prophets ────────────────────────────────────────────────────

/// One prophet a day, in the order the Quran's own narratives run from the first human
/// being to the last messenger. The passages inside each day stay in mushaf order.
export const prophets = [
    { day: 1, title: "Adam, taught the names", refs: ["2:30-39"] },
    { day: 2, title: "Nuh and the ark", refs: ["11:25-49"] },
    { day: 3, title: "Hud and the people of Aad", refs: ["11:50-60"] },
    { day: 4, title: "Salih and the she-camel", refs: ["26:141-159"] },
    { day: 5, title: "Ibrahim looks for his Lord", refs: ["6:74-83"] },
    { day: 6, title: "Ibrahim and the idols", refs: ["21:51-70"] },
    { day: 7, title: "Ibrahim and his son", refs: ["37:99-113"] },
    { day: 8, title: "Lut and the ruined towns", refs: ["11:74-83"] },
    { day: 9, title: "Yusuf and the dream", refs: ["12:4-20"] },
    { day: 10, title: "Shu'ayb and the honest measure", refs: ["11:84-95"] },
    { day: 11, title: "Musa called at the fire", refs: ["20:9-48"] },
    { day: 12, title: "Musa before Pharaoh", refs: ["26:10-68"] },
    { day: 13, title: "Musa and al-Khidr", refs: ["18:60-82"] },
    { day: 14, title: "Dawud and Sulayman judge", refs: ["21:78-82"] },
    { day: 15, title: "Sulayman and the queen", refs: ["27:20-44"] },
    { day: 16, title: "Ayyub, and what was restored", refs: ["21:83-84", "38:41-44"] },
    { day: 17, title: "Yunus in the dark", refs: ["21:87-88", "37:139-148"] },
    { day: 18, title: "Zakariyya asks for an heir", refs: ["19:2-15"] },
    { day: 19, title: "Maryam and the birth of Isa", refs: ["19:16-36"] },
    { day: 20, title: "Isa, announced and sent", refs: ["3:45-59"] },
    { day: 21, title: "The last of them", refs: ["93:1-11", "94:1-8"] },
];

/// Surah Yusuf at its own seams: the dream, the pit, the house, the prison, the court.
export const surahYusuf = surahInSittings(12, [20, 34, 42, 57, 68, 87], [
    "The dream, and the brothers",
    "The house in Egypt",
    "Two companions in prison",
    "The king's dream read",
    "The brothers come for grain",
    "The cup in the saddlebag",
    "Made known, and forgiven",
]);

// ── By theme ───────────────────────────────────────────────────────────────────

export const patience = [
    { day: 1, title: "Seek help through patience", refs: ["2:153"] },
    { day: 2, title: "A test of fear and hunger", refs: ["2:155-157"] },
    { day: 3, title: "Hardship comes with ease", refs: ["94:1-8"] },
    { day: 4, title: "The patience of Yaqub", refs: ["12:83-87"] },
    { day: 5, title: "Ayyub calls on his Lord", refs: ["21:83-84"] },
    { day: 6, title: "Reward without measure", refs: ["39:10"] },
    { day: 7, title: "Patience and prayer together", refs: ["3:200"] },
];

export const gratitude = [
    { day: 1, title: "If you are grateful", refs: ["14:7"] },
    { day: 2, title: "Remember Me and I will remember you", refs: ["2:152"] },
    { day: 3, title: "Countless favours", refs: ["16:18"] },
    { day: 4, title: "The gratitude of Sulayman", refs: ["27:19"] },
    { day: 5, title: "Eat of the good things", refs: ["2:172"] },
    { day: 6, title: "Few of My servants are grateful", refs: ["34:13"] },
    { day: 7, title: "Praise belongs to God", refs: ["1:1-7"] },
];

export const mercy = [
    { day: 1, title: "My mercy encompasses all things", refs: ["7:156"] },
    { day: 2, title: "Do not despair of God's mercy", refs: ["39:53"] },
    { day: 3, title: "A mercy to the worlds", refs: ["21:107"] },
    { day: 4, title: "He prescribed mercy for Himself", refs: ["6:12"] },
    { day: 5, title: "Kindness to parents", refs: ["17:23-24"] },
    { day: 6, title: "The Most Gracious", refs: ["55:1-13"] },
    { day: 7, title: "Forgiveness before punishment", refs: ["15:49-50"] },
];

export const tawbah = [
    { day: 1, title: "God loves those who turn back", refs: ["2:222"] },
    { day: 2, title: "Our Lord, we have wronged ourselves", refs: ["7:23"] },
    { day: 3, title: "Turning while there is time", refs: ["4:17-18"] },
    { day: 4, title: "The three who were left behind", refs: ["9:117-118"] },
    { day: 5, title: "Do not despair of the mercy of God", refs: ["39:53-55"] },
    { day: 6, title: "He accepts the turning of His servants", refs: ["42:25-26"] },
    { day: 7, title: "A turning that holds", refs: ["66:8"] },
];

/// The supplications the Quran records, read in mushaf order.
export const duasOfTheQuran = [
    { day: 1, title: "The prayer the Quran opens with", refs: ["1:1-7"] },
    { day: 2, title: "Raising the foundations", refs: ["2:127-129"] },
    { day: 3, title: "Good in this world and the next", refs: ["2:201-202"] },
    { day: 4, title: "Do not let our hearts deviate", refs: ["3:8-9"] },
    { day: 5, title: "You did not create this in vain", refs: ["3:190-194"] },
    { day: 6, title: "Pour patience upon us", refs: ["7:126"] },
    { day: 7, title: "Make this land secure", refs: ["14:35-41"] },
    { day: 8, title: "Open my chest for me", refs: ["20:25-28"] },
    { day: 9, title: "Refuge from the promptings", refs: ["23:97-98"] },
    { day: 10, title: "Joy in our families", refs: ["25:74"] },
    { day: 11, title: "I am in need of any good", refs: ["28:24"] },
    { day: 12, title: "Let me be thankful for Your favour", refs: ["46:15"] },
    { day: 13, title: "Forgive us, and those before us", refs: ["59:10"] },
    { day: 14, title: "Build me a house near You", refs: ["66:11"] },
];

// ── Memorise ───────────────────────────────────────────────────────────────────

/// The last forty surahs, shortest first. Sorted by ayah count, then by surah number, so
/// the order is fixed by the table rather than by taste.
export const shortSurahs40 = surahs
    .slice(114 - 40)
    .map((s) => s.number)
    .sort((a, b) => surah(a).ayahCount - surah(b).ayahCount || a - b)
    .map((number, i) => ({
        day: i + 1,
        title: `${surah(number).name} — ${surah(number).meaning}`,
        refs: [wholeSurah(number)],
    }));
