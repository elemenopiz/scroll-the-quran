#!/usr/bin/env node
// Builds out/themes.json — the thematic index used as a prompt hint by
// build-requests.mjs and (later) by the Swift ThemeIndex.
//
// SOURCING NOTE (docs/tasks/phase2b-pipeline-scripts.md §2)
// The preferred source is QUL Ayah Themes, resource 62
// (https://qul.tarteel.ai/resources/ayah-theme/62). Checked 2026-09-09: the
// page exposes a single "Download sqlite" button whose target is
// /users/sign_in?...&user_return_to=%2Fresources%2Fayah-theme%2F62 — the
// download is gated behind a QUL account, and QUL states terms per resource
// only after sign-in (site terms: https://www.tarteel.ai/terms). No account
// was created, so no QUL data is used or redistributed here and nothing needs
// to be recorded in ATTRIBUTION.md for it.
//
// Fallback (this file): a hand-curated list of well-known thematic verse
// groups. Mainstream and non-sectarian; the groupings are common to standard
// thematic indexes of the Quran and carry no commentary of their own.
import fs from "node:fs";
import path from "node:path";
import { OUT, loadQuran, refInBounds, parseKey } from "./lib/data.mjs";

export const THEMES = [
  { id: "patience-in-trials", title: "Patience in Trials",
    blurb: "Steadfastness when life is hard, and the promise that hardship is never the whole story.",
    refs: ["2:153-157", "2:286", "3:200", "39:10", "94:5-6", "103:1-3", "21:83-84"] },
  { id: "gratitude", title: "Gratitude",
    blurb: "Thankfulness as a response to blessing, and the promise that gratitude increases what you have.",
    refs: ["14:7", "2:152", "16:18", "31:12", "27:40", "55:13"] },
  { id: "mercy-of-god", title: "The Mercy of God",
    blurb: "Divine mercy as the widest of all attributes, encompassing every created thing.",
    refs: ["39:53", "7:156", "6:54", "15:49", "40:7"] },
  { id: "trust-in-god", title: "Trust in God",
    blurb: "Relying on God after doing your part, and finding a way out where none seemed possible.",
    refs: ["65:2-3", "3:159", "9:51", "8:2", "25:58", "11:88"] },
  { id: "forgiveness", title: "Forgiveness",
    blurb: "Pardoning others, seeking pardon, and the open door of divine forgiveness.",
    refs: ["24:22", "42:40", "7:199", "3:133-136", "41:34-35", "64:14"] },
  { id: "prayer", title: "Prayer",
    blurb: "The daily prayer as an anchor of the day and a restraint from wrongdoing.",
    refs: ["2:238", "29:45", "20:14", "4:103", "107:4-7", "17:78"] },
  { id: "charity", title: "Charity",
    blurb: "Giving as an investment that multiplies, and the manner of giving that preserves dignity.",
    refs: ["2:261-262", "2:274", "3:92", "57:18", "2:271", "9:103"] },
  { id: "family-and-parents", title: "Family and Parents",
    blurb: "Honouring parents, the tranquillity of marriage, and responsibility for one's household.",
    refs: ["17:23-24", "31:14", "46:15", "30:21", "25:74", "66:6"] },
  { id: "justice", title: "Justice",
    blurb: "Standing firmly for fairness, even against your own interest or that of your own people.",
    refs: ["4:135", "5:8", "16:90", "4:58", "49:9", "5:42"] },
  { id: "knowledge", title: "Knowledge",
    blurb: "The call to learn, the first revealed command to read, and the rank of those who know.",
    refs: ["20:114", "96:1-5", "39:9", "58:11", "35:28", "3:190-191"] },
  { id: "death-and-the-hereafter", title: "Death and the Hereafter",
    blurb: "Every soul tastes death, and this life is measured against what comes after it.",
    refs: ["3:185", "21:35", "62:8", "29:57", "23:99-100", "50:19"] },
  { id: "paradise", title: "Paradise",
    blurb: "The gardens promised to the faithful, described in imagery of rest, reunion and peace.",
    refs: ["55:46-61", "56:10-26", "13:23-24", "18:31", "47:15", "76:12-22"] },
  { id: "divine-attributes", title: "The Attributes of God",
    blurb: "Transcendence, knowledge, power, and the names by which God describes Himself.",
    refs: ["42:11", "2:255", "59:22-24", "6:103", "20:110", "57:3"] },
  { id: "revelation-and-its-rejection", title: "Revelation and Its Rejection",
    blurb: "Why revelation is sent, how it is received, and the arguments of those who turn from it.",
    refs: ["6:7-10", "2:23-24", "17:88", "41:26", "25:32", "6:157"] },
  { id: "wealth-and-property", title: "Wealth and Property",
    blurb: "Earning, spending, inheritance, and the trial that possessions become.",
    refs: ["2:188", "4:29", "9:34-35", "64:15", "102:1-8", "2:261-262"] },
  { id: "love-of-god", title: "The Love Between God and the Believer",
    blurb: "God's love for those who turn to Him, and the believer's love expressed in following the Prophet.",
    refs: ["3:31", "5:54", "2:165", "19:96", "85:14", "2:222"] },
  { id: "creation", title: "Creation",
    blurb: "The heavens, the earth, and the signs placed in them for those who reflect.",
    refs: ["2:164", "21:30", "51:47-49", "30:22", "67:3-4", "41:53"] },
  { id: "prophets", title: "The Prophets",
    blurb: "The long line of messengers sent to every people with one essential message.",
    refs: ["21:83-90", "12:4-6", "19:41-50", "2:124", "33:40", "3:33-34"] },
  { id: "repentance", title: "Repentance",
    blurb: "Turning back sincerely, and the mercy that meets the one who turns.",
    refs: ["66:8", "25:70", "24:31", "11:3", "2:222"] },
  { id: "hope", title: "Hope",
    blurb: "Never despairing of God's relief, however long the difficulty lasts.",
    refs: ["12:87", "65:3", "94:5-6", "39:53", "3:139"] },
  { id: "fear-and-hope", title: "Fear and Hope",
    blurb: "The balance of awe and expectation that keeps the heart awake.",
    refs: ["32:16", "7:56", "21:90", "17:57", "13:21"] },
  { id: "humility", title: "Humility",
    blurb: "Walking gently on the earth, and the emptiness of arrogance.",
    refs: ["25:63", "17:37", "31:18-19", "23:1-2", "7:55", "57:16"] },
  { id: "honesty-and-truthfulness", title: "Honesty and Truthfulness",
    blurb: "Being with the truthful, keeping full measure, and matching words to deeds.",
    refs: ["9:119", "33:70-71", "2:42", "17:35", "61:2-3"] },
  { id: "community-and-brotherhood", title: "Community and Brotherhood",
    blurb: "Holding together, reconciling, and the dignity every human being is owed.",
    refs: ["49:10", "3:103", "49:11-13", "5:2", "9:71", "8:46"] },
  { id: "guidance", title: "Guidance",
    blurb: "Asking for the straight path, and the Quran as guidance for those who are open to it.",
    refs: ["1:6-7", "2:2", "2:185", "17:9", "6:125", "39:23"] },
  { id: "light", title: "Light",
    blurb: "Light as an image of God, of revelation, and of a heart brought out of darkness.",
    refs: ["24:35", "5:15-16", "65:11", "33:45-46", "2:257", "39:22"] },
  { id: "supplication", title: "Supplication (Dua)",
    blurb: "Calling on God directly, and the assurance that the call is heard.",
    refs: ["2:186", "40:60", "7:55", "25:74", "20:25-28", "3:8"] },
  { id: "ramadan-and-fasting", title: "Ramadan and Fasting",
    blurb: "The month of revelation, the discipline of the fast, and the night of decree.",
    refs: ["2:183-185", "2:187", "97:1-5", "2:186"] },
  { id: "pilgrimage", title: "Pilgrimage",
    blurb: "The rites of Hajj, the first house of worship, and the inner meaning of the journey.",
    refs: ["2:196-197", "3:96-97", "22:26-29", "2:125", "22:32"] },
  { id: "provision-and-sustenance", title: "Provision and Sustenance",
    blurb: "Where livelihood comes from, and why anxiety about it is misplaced.",
    refs: ["65:2-3", "51:22", "17:30", "62:10", "42:27", "11:6"] },
  { id: "contentment", title: "Contentment",
    blurb: "Not straining after what others have, and preferring the lasting to the passing.",
    refs: ["20:131", "57:23", "87:16-17", "28:77", "93:4-5"] },
  { id: "worship-and-devotion", title: "Worship and Devotion",
    blurb: "The purpose of creation expressed as worship offered sincerely.",
    refs: ["51:56", "98:5", "6:162-163", "2:21", "39:2"] },
  { id: "remembrance-of-god", title: "Remembrance of God",
    blurb: "Dhikr as what settles the heart and keeps God present in an ordinary day.",
    refs: ["13:28", "33:41-42", "2:152", "63:9", "29:45", "8:2"] },
  { id: "purpose-of-life", title: "The Purpose of Life",
    blurb: "Why humanity is here: a trust, a test, and a short span in which to answer it.",
    refs: ["51:56", "67:2", "2:30", "23:115", "76:2-3"] },
  { id: "the-quran", title: "The Quran Itself",
    blurb: "Revelation described as healing, reminder, and a book made easy to remember.",
    refs: ["17:82", "2:2", "54:17", "59:21", "41:41-42", "38:29"] },
  { id: "angels", title: "Angels",
    blurb: "The unseen servants of God: recorders, messengers and guardians.",
    refs: ["2:285", "66:6", "13:11", "82:10-12", "35:1", "97:4"] },
  { id: "good-character", title: "Good Character",
    blurb: "The moral shape of a believing life: restraint, gentleness, and repelling harm with good.",
    refs: ["68:4", "41:34-35", "3:134", "31:18-19", "25:63", "17:53"] },
  { id: "speech-and-the-tongue", title: "Speech and the Tongue",
    blurb: "Words that build and words that wound: backbiting, ridicule and upright speech.",
    refs: ["33:70-71", "49:11-12", "17:53", "2:83", "4:148", "24:15-16"] },
  { id: "the-heart", title: "The Heart",
    blurb: "The inner organ of perception — what hardens it, what softens it, what heals it.",
    refs: ["22:46", "50:37", "26:88-89", "2:74", "13:28", "83:14"] },
  { id: "greed-and-generosity", title: "Greed and Generosity",
    blurb: "The pull of accumulation, and the freedom of those saved from their own stinginess.",
    refs: ["59:9", "92:5-10", "3:180", "102:1-3", "64:16"] },
  { id: "time-and-life", title: "Time and the Brevity of Life",
    blurb: "The shortness of the human span measured against what it is spent on.",
    refs: ["103:1-3", "23:112-114", "3:185", "79:46", "10:45"] },
  { id: "adam-and-the-human-story", title: "Adam and the Human Story",
    blurb: "The first human being, the trust given, the slip, and the words of return.",
    refs: ["2:30-34", "2:35-37", "7:19-25", "20:115-122"] },
  { id: "moses", title: "Moses",
    blurb: "The prophet raised in Pharaoh's house, sent back to confront him, and given the sea as a road.",
    refs: ["20:9-24", "26:10-22", "28:7-13", "20:65-70"] },
  { id: "jesus-son-of-mary", title: "Jesus, Son of Mary",
    blurb: "The Messiah as the Quran presents him: servant, prophet, and a word from God.",
    refs: ["3:45-47", "19:16-34", "5:110", "3:59", "4:171", "43:57-59"] },
  { id: "mary", title: "Mary",
    blurb: "The only woman named in the Quran, chosen and purified, and the birth beneath the palm.",
    refs: ["3:42-43", "19:16-26", "66:12", "21:91", "3:35-37"] },
  { id: "joseph", title: "Joseph",
    blurb: "The most beautifully told story: betrayal, patience, prison, and a reunion that forgives.",
    refs: ["12:4-6", "12:23-24", "12:87", "12:90-92", "12:100-101"] },
  { id: "abraham", title: "Abraham",
    blurb: "The seeker who questioned the stars, built the House, and was tested to the limit.",
    refs: ["2:124-129", "6:74-79", "14:35-41", "21:51-70", "37:100-111"] },
  { id: "noah", title: "Noah",
    blurb: "Centuries of unanswered calling, the ark, and a father's grief.",
    refs: ["71:1-10", "11:36-44", "26:105-122", "29:14", "54:9-15"] },
  { id: "solomon-and-david", title: "Solomon and David",
    blurb: "Kingship given as a trust, gratitude for gifts, and judgement between people.",
    refs: ["27:15-19", "34:10-13", "38:17-26", "21:78-82", "27:38-40"] },
  { id: "night-and-day", title: "Night and Day",
    blurb: "The night vigil, the alternation of light and dark, and rest as a mercy.",
    refs: ["17:78-79", "73:1-8", "51:15-18", "3:190", "25:47", "78:9-11"] },
  { id: "rain-and-the-earth", title: "Rain and the Living Earth",
    blurb: "Water sent down as the standing sign of resurrection and of renewal.",
    refs: ["30:48-50", "50:9-11", "2:164", "16:65", "7:57", "22:5"] },
  { id: "the-day-of-judgement", title: "The Day of Judgement",
    blurb: "The hour described in short, vivid surahs: the earth shaken, the record read.",
    refs: ["99:1-8", "82:1-5", "81:1-14", "101:1-11", "75:1-15", "39:68-70"] },
  { id: "protection-and-refuge", title: "Protection and Refuge",
    blurb: "Seeking shelter in God from every kind of harm, seen and unseen.",
    refs: ["113:1-5", "114:1-6", "2:255", "3:173", "9:51", "21:87"] },
  { id: "sincerity", title: "Sincerity",
    blurb: "Doing what you do for God alone, with nothing added underneath it.",
    refs: ["98:5", "112:1-4", "6:162-163", "2:264", "39:2-3"] },
];

function main() {
  const quran = loadQuran();
  const errors = [];
  const ids = new Set();

  for (const t of THEMES) {
    if (!/^[a-z0-9-]+$/.test(t.id)) errors.push(`bad id: ${t.id}`);
    if (ids.has(t.id)) errors.push(`duplicate id: ${t.id}`);
    ids.add(t.id);
    if (!t.title || !t.blurb) errors.push(`${t.id}: missing title/blurb`);
    if (!Array.isArray(t.refs) || t.refs.length < 3) errors.push(`${t.id}: needs >= 3 refs`);
    for (const r of t.refs) {
      if (!refInBounds(r, quran.byNumber)) errors.push(`${t.id}: ref out of bounds: ${r}`);
    }
    if (new Set(t.refs).size !== t.refs.length) errors.push(`${t.id}: duplicate refs`);
  }
  if (THEMES.length < 40) errors.push(`only ${THEMES.length} themes, need >= 40`);
  if (errors.length) {
    for (const e of errors) console.error(`ERROR ${e}`);
    process.exit(1);
  }

  // Reverse index: unit-resolvable ayah key -> theme ids, for the prompt hint.
  const byAyah = {};
  for (const t of THEMES) {
    for (const r of t.refs) {
      const p = parseKey(r);
      for (let a = p.start; a <= p.end; a++) {
        (byAyah[`${p.surah}:${a}`] ??= []).push(t.id);
      }
    }
  }

  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(
    path.join(OUT, "themes.json"),
    JSON.stringify({ source: "hand-curated (QUL Ayah Themes 62 is sign-in gated)", themes: THEMES }, null, 2) + "\n",
  );
  fs.writeFileSync(path.join(OUT, "themes-index.json"), JSON.stringify(byAyah) + "\n");

  console.log(`themes:        ${THEMES.length}`);
  console.log(`refs:          ${THEMES.reduce((n, t) => n + t.refs.length, 0)} (all in bounds)`);
  console.log(`ayat tagged:   ${Object.keys(byAyah).length}`);
  console.log(`wrote out/themes.json and out/themes-index.json`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
