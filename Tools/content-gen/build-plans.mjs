#!/usr/bin/env node
// Builds Content/plans.json from the catalogue in `plans/`.
//
//   node Tools/content-gen/build-plans.mjs
//
// Nothing in the output is hand-written JSON. The shelves and the card copy live in
// `plans/catalogue.mjs`, the day-by-day schedules in `plans/schedules.mjs`, and the mushaf
// arithmetic — surah table, juz and hizb boundaries, English word counts — in
// `plans/mushaf.mjs`. `dailyMinutes` is computed from the schedule, never typed.
//
// The script is deterministic: it reads only committed content plus Tanzil's
// `quran-data.xml` (run `node Tools/content-gen/fetch-inputs.mjs` once to cache it), and
// running it twice leaves `Content/plans.json` byte-identical.
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { plans as authored, sections } from "./plans/catalogue.mjs";
import { ROOT, dailyMinutes, parseRef, surah } from "./plans/mushaf.mjs";

/// Mirrors `PlanCoverArtwork.slugs` in `Packages/ScrollKit/Sources/FeatureHome`. When a
/// cover is added, both tables move; a plan naming a slug that is not here draws the
/// fallback wash, so the mismatch is caught at build time instead of on screen.
const COVER_SLUGS = new Set([
    "mushaf-page", "prayer-beads", "geometric-tile", "dawn-light",
    "lantern", "ink-wash", "desert-dune", "olive-branch",
]);

const ABOUT_WORDS = [60, 120];
const SUBTITLE_WORDS = 6;
/// The `dailyMinutes` the plan card can print without the meta line looking absurd; the
/// same bounds the Swift catalogue test asserts.
const MINUTE_BOUNDS = [3, 90];
const START_HERE_COUNT = 4;

const problems = [];
const check = (condition, message) => {
    if (!condition) problems.push(message);
};
const words = (text) => text.trim().split(/\s+/).filter(Boolean).length;

// Prose rules from docs/tasks/content-author.md, applied to the only prose these cards
// carry. They are cheap regressions guards, not a substitute for reading the copy.
const ARABIC_SCRIPT = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/;
const PRESCRIPTIVE = /\b(you must|you should|it is obligatory|you are required|forbidden|haram|thou shalt)\b/i;
const SECTARIAN = /\b(Sunni|Shia|Shi'a|Shiite|Salafi|Sufi|Hanafi|Maliki|Shafi'i|Hanbali|Wahhabi|Ash'ari|Maturidi|Mu'tazil\w*)\b/i;

function checkProse(id, field, text) {
    check(!ARABIC_SCRIPT.test(text), `${id}: ${field} contains Arabic script; the app draws the muted line`);
    check(!/\bAllah\b/.test(text), `${id}: ${field} says "Allah"; English prose uses "God"`);
    check(!PRESCRIPTIVE.test(text), `${id}: ${field} reads as a ruling, not a description`);
    check(!SECTARIAN.test(text), `${id}: ${field} names a school or sect`);
    const honorifics = (text.match(/\(peace be upon him\)/g) ?? []).length;
    check(honorifics <= 1, `${id}: ${field} uses the honorific ${honorifics} times; once per note`);
    const bareName = /\bMuhammad\b(?!\s*\(peace be upon him\))/.test(text);
    check(
        !bareName || honorifics === 1,
        `${id}: ${field} names Muhammad without the honorific`,
    );
}

const plans = authored.map((plan) => {
    const { schedule } = plan;
    check(schedule.length > 0, `${plan.id}: empty schedule`);
    check(
        schedule.every((day, i) => day.day === i + 1),
        `${plan.id}: schedule days are not 1..${schedule.length} in order`,
    );

    for (const day of schedule) {
        check(day.refs.length > 0, `${plan.id} day ${day.day}: no refs`);
        check(day.title.trim().length > 0, `${plan.id} day ${day.day}: no title`);
        for (const ref of day.refs) {
            try {
                // Throws on a ref that is not a whole-ayah passage inside the Quran.
                const passage = parseRef(ref);
                check(
                    passage.end <= surah(passage.surah).ayahCount,
                    `${plan.id} day ${day.day}: ${ref} runs past ${surah(passage.surah).name}`,
                );
            } catch (error) {
                problems.push(`${plan.id} day ${day.day}: ${error.message}`);
            }
        }
    }

    check(COVER_SLUGS.has(plan.image), `${plan.id}: "${plan.image}" is not a cover slug`);
    check(
        words(plan.subtitle) <= SUBTITLE_WORDS,
        `${plan.id}: subtitle is ${words(plan.subtitle)} words, at most ${SUBTITLE_WORDS}`,
    );
    const aboutWords = words(plan.about);
    check(
        aboutWords >= ABOUT_WORDS[0] && aboutWords <= ABOUT_WORDS[1],
        `${plan.id}: about is ${aboutWords} words, must be ${ABOUT_WORDS[0]}-${ABOUT_WORDS[1]}`,
    );
    check(plan.bestFor.trim().length > 0, `${plan.id}: no bestFor line`);
    checkProse(plan.id, "about", plan.about);
    checkProse(plan.id, "title", plan.title);
    checkProse(plan.id, "subtitle", plan.subtitle);
    checkProse(plan.id, "bestFor", plan.bestFor);

    const minutes = dailyMinutes(schedule);
    check(
        minutes >= MINUTE_BOUNDS[0] && minutes <= MINUTE_BOUNDS[1],
        `${plan.id}: computed dailyMinutes ${minutes} is outside ${MINUTE_BOUNDS.join("-")}`,
    );

    return {
        id: plan.id,
        title: plan.title,
        subtitle: plan.subtitle,
        image: plan.image,
        ...(plan.startHere ? { startHere: true } : {}),
        section: plan.section,
        bestFor: plan.bestFor,
        lengthDays: schedule.length,
        dailyMinutes: minutes,
        about: plan.about,
        schedule,
    };
});

const planIDs = new Set(plans.map((p) => p.id));
check(planIDs.size === plans.length, "two plans share an id");
check(
    plans.filter((p) => p.startHere).length === START_HERE_COUNT,
    `startHere is set on ${plans.filter((p) => p.startHere).length} plans, expected ${START_HERE_COUNT}`,
);

const listed = new Map();
for (const section of sections) {
    check(section.planIDs.length > 0, `section "${section.title}" lists no plans`);
    for (const id of section.planIDs) {
        check(planIDs.has(id), `section "${section.title}" lists unknown plan "${id}"`);
        check(!listed.has(id), `plan "${id}" is listed in two sections`);
        listed.set(id, section.title);
    }
}
for (const plan of plans) {
    check(listed.has(plan.id), `plan "${plan.id}" is in no section`);
    check(
        listed.get(plan.id) === plan.section,
        `plan "${plan.id}" names section "${plan.section}" but is listed under "${listed.get(plan.id)}"`,
    );
}
// The beginner shelf is two rows of two in the reference; a third row pushes the next
// section's heading off the `plans-sheet` capture entirely.
check(
    sections[0].planIDs.length === START_HERE_COUNT,
    `the first shelf holds ${sections[0].planIDs.length} plans, expected ${START_HERE_COUNT}`,
);
check(
    sections[0].planIDs.every((id) => plans.find((p) => p.id === id)?.startHere),
    "the first shelf lists a plan without startHere",
);

if (problems.length > 0) {
    console.error(`build-plans: ${problems.length} problem(s)`);
    for (const problem of problems) console.error(`  ${problem}`);
    process.exit(1);
}

const out = {
    version: 1,
    generatedBy: "Tools/content-gen/build-plans.mjs",
    sections,
    plans,
};

await writeFile(join(ROOT, "Content", "plans.json"), `${JSON.stringify(out, null, 2)}\n`);
const days = plans.reduce((n, p) => n + p.schedule.length, 0);
console.log(`plans.json   ${plans.length} plans in ${sections.length} sections, ${days} scheduled days`);
for (const section of sections) {
    const line = section.planIDs
        .map((id) => {
            const plan = plans.find((p) => p.id === id);
            return `${id} (${plan.lengthDays}d, ${plan.dailyMinutes}m, ${plan.image})`;
        })
        .join(", ");
    console.log(`  ${section.title}: ${line}`);
}
