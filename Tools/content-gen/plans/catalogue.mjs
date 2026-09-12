// The reading-plan catalogue: the shelves, and the copy on every card.
//
// House rules this file follows, enforced by the assertions in `build-plans.mjs`:
//   * `subtitle` is at most six words; `about` is 60-120 words.
//   * `about` is descriptive, never an instruction. Where a plan follows a practice the
//     hadith collections record, the `about` names the collection in a clause ("reported
//     in ...") and says what the report says, not what the reader must do.
//   * "God" in English prose, never the Arabic name; the Prophet Muhammad (peace be upon
//     him) carries the honorific once in the note that names him, "the Prophet" after.
//   * No transliterated Arabic in prose. Arabic reaches the reader only as the muted line
//     the app draws above each ayah. Structural words the English has borrowed outright
//     (surah, ayah, juz, hizb, mushaf) are English words here and are used as such.
//   * No school, sect or movement is named, and nothing is framed as a ruling.
//   * `dailyMinutes` is absent on purpose: `build-plans.mjs` computes it from the schedule.
//   * `image` is one of `PlanCoverArtwork.slugs`; reuse is fine, mood is what matters.
import * as schedule from "./schedules.mjs";

export const BEGINNERS = "Recommended for beginners";
export const THROUGH = "Read it through";
export const SUNNAH = "The Sunnah of reading";
export const PROPHETS = "Stories of the prophets";
export const THEME = "By theme";
export const MEMORISE = "Memorise";

export const plans = [
    // ── Recommended for beginners ──────────────────────────────────────────────
    {
        id: "first-week",
        title: "Your first week",
        subtitle: "Seven short readings",
        image: "dawn-light",
        startHere: true,
        section: BEGINNERS,
        bestFor: "Day one, if you have never opened it",
        about:
            "Seven days, seven short readings, each of them a passage a new reader is usually handed first. " +
            "The opening surah, because every prayer contains it. The Throne Verse and the last two lines of " +
            "Al-Baqarah, because those are what people recite at night. Al-Ikhlas and the two surahs of refuge, " +
            "learned before almost anything else. Then Al-Asr, three lines that the early Muslims are reported " +
            "to have said to one another before parting, and Al-Kawthar, the shortest surah in the book. None " +
            "of them takes more than a minute, and together they cover most of what you will hear recited " +
            "around you.",
        schedule: schedule.firstWeek,
    },
    {
        id: "juz-amma",
        title: "Juz Amma",
        subtitle: "One short surah a day",
        image: "lantern",
        startHere: true,
        section: BEGINNERS,
        bestFor: "Short sittings and the surahs you hear in prayer",
        about:
            "The final thirtieth of the Quran holds the short Meccan surahs that children learn first and that " +
            "adults hear most, because these are what get recited in prayer. Thirty-seven of them, one a day, " +
            "from the long questioning opening of An-Naba down to the six lines of An-Nas. They are dense, " +
            "rhythmic, and mostly about one thing: that this life is answered for. Starting at the back of " +
            "the book feels wrong for about a page and then feels obvious, which is why it is where nearly " +
            "every new reader is pointed.",
        schedule: schedule.juzAmma,
    },
    {
        id: "protection-verses",
        title: "The verses of refuge",
        subtitle: "Before sleep, after prayer",
        image: "geometric-tile",
        startHere: true,
        section: BEGINNERS,
        bestFor: "The last thing you read at night",
        about:
            "A week with the passages readers return to nightly: the Throne Verse, the two verses that follow " +
            "it, the closing verses of Al-Baqarah, and Al-Ikhlas with the two surahs of refuge. The classical " +
            "collections group them under the reading done before sleep and after prayer, and between them " +
            "they say very little about danger and a great deal about who is being asked. The last day puts " +
            "all of them into one sitting, which is how most people who keep the habit actually read them.",
        schedule: schedule.protection,
    },
    {
        id: "al-kahf-fridays",
        title: "Al-Kahf on Fridays",
        subtitle: "The Cave, in four sittings",
        image: "ink-wash",
        startHere: true,
        section: BEGINNERS,
        bestFor: "Keeping the Friday habit",
        about:
            "Reading Surah Al-Kahf on Friday is among the most widely kept weekly habits in Muslim life, and " +
            "it rests on reports preserved in the collections of al-Hakim and al-Bayhaqi describing a light " +
            "that shines for the reader between the two Fridays. The surah itself divides cleanly into four " +
            "stories: young men who sleep in a cave for three centuries, two neighbours and their gardens, " +
            "Musa travelling with a teacher he cannot understand, and a king who reaches the ends of the " +
            "earth. One story a week, and the whole surah is behind you in a month.",
        schedule: schedule.alKahfFridays,
    },

    // ── Read it through ────────────────────────────────────────────────────────
    {
        id: "juz-a-day",
        title: "A juz a day",
        subtitle: "One juz every day",
        image: "mushaf-page",
        section: THROUGH,
        bestFor: "Anyone who wants the whole book, once",
        about:
            "The thirtieth part of the Quran called a juz has been the unit of daily reading for centuries, " +
            "and it is marked in the margin of almost every printed mushaf. This plan walks the book in the " +
            "order it is written, from the opening surah to the last, including the long middle that most " +
            "readers never reach. Some days sit heavier than others, because the divisions fall where the " +
            "page falls rather than where the subject changes. It takes a month, and it tends to change what " +
            "a reader thinks the Quran is.",
        schedule: schedule.juzADay,
    },
    {
        id: "khatm-60",
        title: "A hizb a day",
        subtitle: "Half a juz every day",
        image: "prayer-beads",
        section: THROUGH,
        bestFor: "Finishing the book without losing the week",
        about:
            "Half a juz is a hizb, and the sixty of them are printed in the margins of the mushaf alongside " +
            "the juz numbers. At one a day the whole book takes two months, and a single sitting stays short " +
            "enough to survive an ordinary working week. This is the pace readers fall back to when a juz a " +
            "day turns out to be too much and stopping altogether turns out to be too easy. The divisions are " +
            "the printed ones, so you can follow along in any copy you own and always know where you are.",
        schedule: schedule.khatm60,
    },
    {
        id: "ramadan-khatm",
        title: "A Ramadan reading",
        subtitle: "One juz a night",
        image: "lantern",
        section: THROUGH,
        bestFor: "Ramadan, or any month you want to give over",
        about:
            "Completing the whole Quran across Ramadan is the oldest habit of the month: one of the thirty " +
            "portions each night, so the last of them lands as the fast ends. The reading is the mushaf's own " +
            "division, counted by night rather than by day, because the night is when the month's long " +
            "congregational prayers happen. Many communities keep their longest vigil on the twenty-seventh, " +
            "hoping it is the Night of Decree that the short surah Al-Qadr describes; the reports place that " +
            "night somewhere in the last ten without fixing it, and the reading continues either way.",
        schedule: schedule.ramadanKhatm,
    },

    // ── The Sunnah of reading ──────────────────────────────────────────────────
    {
        id: "mulk-every-night",
        title: "Al-Mulk before sleep",
        subtitle: "Three ayat a night",
        image: "lantern",
        section: SUNNAH,
        bestFor: "The last few minutes of the day",
        about:
            "Surah Al-Mulk read at night is among the best attested of all reading habits, reported in the " +
            "collection of at-Tirmidhi, where it is described as a surah of thirty verses that speaks for the " +
            "one who keeps it. This plan walks those thirty verses three at a time, so ten nights carry you " +
            "through the whole surah slowly enough to notice what it does: it looks up, then it looks down, " +
            "and it keeps asking whether you have looked again. After ten nights most readers simply read the " +
            "surah whole, which is the practice the reports describe.",
        schedule: schedule.mulkEveryNight,
    },
    {
        id: "baqarah-nights",
        title: "Al-Baqarah at night",
        subtitle: "The last two verses",
        image: "geometric-tile",
        section: SUNNAH,
        bestFor: "A nightly reading short enough to keep",
        about:
            "The two verses that close Al-Baqarah are the ones reports in the collections of al-Bukhari and " +
            "Muslim single out for the night, saying that whoever reads them at night is sufficed by them. " +
            "They are an unusual pair to say in the dark: first a declaration that no distinction is drawn " +
            "between God's messengers, then a run of requests ending with a plea that what a person cannot " +
            "carry not be laid on them. Most nights here sit with a single line. A report preserved by an-Nasa'i " +
            "attaches the Throne Verse to the end of every prayer, which pairs naturally with this week.",
        schedule: schedule.baqarahNights,
    },
    {
        id: "three-quls-morning-evening",
        title: "Morning and evening",
        subtitle: "The three short refuges",
        image: "dawn-light",
        section: SUNNAH,
        bestFor: "Bookending an ordinary day",
        about:
            "Al-Ikhlas with the two surahs of refuge, said three times after dawn and again at dusk, is one of " +
            "the few daily readings with a plain report behind it: the collections of Abu Dawud and " +
            "at-Tirmidhi preserve a companion being told that these three, morning and evening, would suffice " +
            "him against everything. Fifteen short lines in total. A week of them costs almost no time and " +
            "tends to stick, which is rather the point, since the readings people actually keep are the ones " +
            "short enough to say while the kettle boils.",
        schedule: schedule.threeQuls,
    },

    // ── Stories of the prophets ────────────────────────────────────────────────
    {
        id: "prophets-in-the-quran",
        title: "The prophets",
        subtitle: "One prophet a day",
        image: "desert-dune",
        section: PROPHETS,
        bestFor: "Readers who know the names but not the stories",
        about:
            "The Quran does not tell the prophets' stories in one place. It returns to them surah by surah, " +
            "from different angles and for different reasons, so a reader meets Musa a dozen times before " +
            "meeting him whole. This plan gathers the fullest telling of each into a single day, running from " +
            "the first human being to the last messenger, with the passages inside a day kept in the order " +
            "the mushaf has them. Some are long narratives; others are a handful of lines that assume you " +
            "already know the rest. Read in a row they make one argument, repeated twenty-one times.",
        schedule: schedule.prophets,
    },
    {
        id: "surah-yusuf",
        title: "Surah Yusuf",
        subtitle: "One story, start to finish",
        image: "ink-wash",
        section: PROPHETS,
        bestFor: "A week when you want a story, not fragments",
        about:
            "Surah Yusuf is the only place in the Quran where a single story runs from beginning to end " +
            "without interruption, and the surah says as much about itself in its third verse. A boy dreams, " +
            "his brothers drop him down a well, and what follows moves through an Egyptian household, a " +
            "prison, a palace and a famine before the family stands in one room again. Underneath the plot it " +
            "is about being wronged by people you cannot stop loving. Seven sittings follow the surah's own " +
            "turns, and the last of them is the reunion.",
        schedule: schedule.surahYusuf,
    },

    // ── By theme ───────────────────────────────────────────────────────────────
    {
        id: "patience",
        title: "Patience",
        subtitle: "A week of holding steady",
        image: "desert-dune",
        section: THEME,
        bestFor: "A hard stretch",
        about:
            "Patience in the Quran is not passivity and it is not silence. The word covers holding a position " +
            "under pressure: staying honest while a thing is still unresolved, continuing to act when nothing " +
            "you do seems to be working, and refusing to make the situation worse. It turns up beside prayer " +
            "far more often than beside suffering, which tells you what kind of effort is meant. This week " +
            "takes seven passages from seven surahs: a test named in advance, a bereaved father, a sick " +
            "prophet, and the promise that the reward for this one thing is never measured out.",
        schedule: schedule.patience,
    },
    {
        id: "gratitude",
        title: "Gratitude",
        subtitle: "A week of noticing",
        image: "olive-branch",
        section: THEME,
        bestFor: "Resetting how the day feels",
        about:
            "Gratitude in the Quran is closer to acknowledgement than to feeling. It means noticing that " +
            "something was given, saying so out loud, and then using it in a way that matches where it came " +
            "from, which is why it stands opposite denial rather than opposite complaint. The passages here " +
            "move from the promise that thankfulness increases what you hold, through a king startled into it " +
            "by an ant, to a plain admission that few people manage it at all. The week ends with the opening " +
            "surah, which is a thanksgiving before it is anything else.",
        schedule: schedule.gratitude,
    },
    {
        id: "mercy",
        title: "Mercy",
        subtitle: "A week with the door open",
        image: "dawn-light",
        section: THEME,
        bestFor: "When you are not sure you are welcome",
        about:
            "Mercy is the attribute the Quran opens with, names twice in its first line, and returns to more " +
            "often than any other. This week follows it outward: mercy that covers everything that exists, " +
            "mercy promised to people who have wrecked their own lives, a messenger described as a mercy sent " +
            "to the worlds, and then the turn where mercy stops being something received and becomes " +
            "something asked of the reader, towards parents first. The last day sets forgiveness and " +
            "punishment side by side, in the order the Quran almost always puts them.",
        schedule: schedule.mercy,
    },
    {
        id: "tawbah",
        title: "Turning back",
        subtitle: "A week on repentance",
        image: "olive-branch",
        section: THEME,
        bestFor: "After something you would rather undo",
        about:
            "Repentance in the Quran is a turning, and the same word describes God turning towards the person " +
            "who turns. The movement goes both ways, and that is the whole shape of it. This week opens with " +
            "the statement that God loves those who keep coming back, passes through the words Adam is given " +
            "to say after his mistake, and spends a day on three men whose community stopped speaking to them " +
            "until the verses about them arrived. It is deliberately not a week about guilt: every passage " +
            "here is about what happens afterwards, and most of them are relieved rather than severe.",
        schedule: schedule.tawbah,
    },
    {
        id: "duas-of-the-quran",
        title: "Prayers in the Quran",
        subtitle: "Fourteen days of asking",
        image: "prayer-beads",
        section: THEME,
        bestFor: "Learning what to ask for",
        about:
            "The Quran records dozens of supplications inside its own narratives: what Ibrahim said while " +
            "laying the foundations of a house, what Musa asked for before speaking to a king, what a woman " +
            "in Pharaoh's household asked for while still married to him. This plan reads fourteen of them in " +
            "the order the mushaf has them, beginning with the opening surah, which is itself a request. They " +
            "are short, they are specific, and almost none of them ask for what you would expect. Read in a " +
            "row they teach a grammar of asking rather than a list of things to want.",
        schedule: schedule.duasOfTheQuran,
    },

    // ── Memorise ───────────────────────────────────────────────────────────────
    {
        id: "short-surahs-40",
        title: "Forty short surahs",
        subtitle: "Shortest first, one a day",
        image: "mushaf-page",
        section: MEMORISE,
        bestFor: "Starting to memorise",
        about:
            "The last forty surahs of the mushaf, re-ordered by length so the shortest come first. The order " +
            "is the only thing that changes: three lines on day one, and a surah of fifty by the end of the " +
            "forty days. Memorising almost always starts in this part of the book, and starting with the " +
            "shortest means the first week hands you several whole surahs rather than a fraction of one, " +
            "which is what keeps people going. These are also the surahs you hear most in prayer, so what you " +
            "keep will come back to you unsought.",
        schedule: schedule.shortSurahs40,
    },
];

// Sections carry their own copy and their own order: a shelf is sequenced by how a reader
// should meet it, not by the order the plans happen to be defined in above. Every plan's
// `section` must name one of these titles, and every id listed here must exist; both are
// asserted in `build-plans.mjs`.
export const sections = [
    {
        title: BEGINNERS,
        eyebrow: "For new readers",
        blurb:
            "Never opened the Quran before, or not sure where to start? Any of these works on its own — " +
            "short, in order, and no prior reading needed.",
        planIDs: ["first-week", "juz-amma", "protection-verses", "al-kahf-fridays"],
    },
    {
        title: THROUGH,
        eyebrow: "Start to finish",
        blurb:
            "The whole mushaf, in the order it is written, at the pace Muslims have read it for centuries.",
        planIDs: ["juz-a-day", "khatm-60", "ramadan-khatm"],
    },
    {
        title: SUNNAH,
        eyebrow: "As it has been read",
        blurb:
            "Reading habits the hadith collections record — at night, after dawn, at the end of the day. " +
            "Each plan names the collection its practice is reported in, and describes it rather than asking " +
            "anything of you.",
        planIDs: ["mulk-every-night", "baqarah-nights", "three-quls-morning-evening"],
    },
    {
        title: PROPHETS,
        eyebrow: "The narratives",
        blurb:
            "The Quran tells its stories in pieces, scattered across surahs and told for different reasons. " +
            "These put them back into one line.",
        planIDs: ["prophets-in-the-quran", "surah-yusuf"],
    },
    {
        title: THEME,
        eyebrow: "One idea at a time",
        blurb: "A week with a single theme, followed through the Quran verse by verse.",
        planIDs: ["patience", "gratitude", "mercy", "tawbah", "duas-of-the-quran"],
    },
    {
        title: MEMORISE,
        eyebrow: "Worth keeping by heart",
        blurb:
            "The short surahs, in the order that makes them easiest to hold on to. Nothing here runs longer " +
            "than a page.",
        planIDs: ["short-surahs-40"],
    },
];
