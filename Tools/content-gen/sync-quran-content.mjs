#!/usr/bin/env node
// Puts the bundled Quran text into Content/quran/.
//
//   node Tools/content-gen/sync-quran-content.mjs            # sync (copy from out/, else download)
//   node Tools/content-gen/sync-quran-content.mjs --fetch    # force the download path
//   node Tools/content-gen/sync-quran-content.mjs --offline  # only use the HTTP cache in work/
//   node Tools/content-gen/sync-quran-content.mjs --verify   # re-check Content/quran from disk, no writes
//
// Two inputs, in order of preference:
//   1. Tools/content-gen/out/quran/*.json — produced by the 2a-data ingest task. Copied verbatim.
//   2. The upstream sources below, downloaded and cached in Tools/content-gen/work/.
//
// Writes flat 6,236-string arrays (index = surah.startIndex + ayah - 1):
//   Content/quran/arabic-uthmani.json  Tanzil Uthmani, CC BY 3.0
//   Content/quran/saheeh.json          Saheeh International via QuranEnc
//   Content/quran/ruwwad.json          Ruwwad Translation Center via QuranEnc
//   Content/quran/pickthall.json       Marmaduke Pickthall, public domain
// and refreshes the Content/quran/translations.json registry.
//
// Content/ is generated: edit this script, not its output. surahs.json and itani.json stay
// the property of ingest-quran-data.mjs; this script only reads them.
import { copyFile, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CACHE = join(ROOT, "Tools", "content-gen", "work");
const INBOX = join(ROOT, "Tools", "content-gen", "out", "quran");
const OUT = join(ROOT, "Content", "quran");

const TOTAL_AYAT = 6236;
const SURAH_COUNT = 114;

// Arabic script blocks. Arabic entries must match; translation entries must not.
const ARABIC = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/;

const CDN = "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions";
const QURANENC = "https://quranenc.com/api/v1/translation/sura";
const TANZIL_DOWNLOAD = "https://tanzil.net/pub/download/download.php";

/** Honorifics QuranEnc writes as Arabic presentation-form ligatures. Spelled out, never dropped. */
const LIGATURES = [
    [/ﷺ/g, "(peace and blessings be upon him)"],
    [/ﷻ/g, "(exalted is His Majesty)"],
    [/ﷲ/g, "Allah"],
    [/﷽/g, "In the name of Allah, the Most Gracious, the Most Merciful"],
];

const args = new Set(process.argv.slice(2));
const OFFLINE = args.has("--offline");
const FORCE_FETCH = args.has("--fetch");
const VERIFY_ONLY = args.has("--verify");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function cachedFetch(name, url, init) {
    await mkdir(CACHE, { recursive: true });
    const cached = join(CACHE, name);
    if (existsSync(cached)) return readFile(cached, "utf8");
    if (OFFLINE) throw new Error(`--offline and no cached ${cached}`);
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
        try {
            const response = await fetch(url, init);
            if (!response.ok) throw new Error(`${init?.method ?? "GET"} ${url} -> ${response.status}`);
            const body = await response.text();
            await writeFile(cached, body);
            return body;
        } catch (error) {
            lastError = error;
            if (attempt < 3) await sleep(400 * attempt);
        }
    }
    throw lastError;
}

/** Collapse whitespace; leave every word alone (CC BY-ND forbids derivatives). */
const tidy = (value) => String(value).replace(/\s+/g, " ").trim();

/** QuranEnc ships footnote markers like "[2]" and the occasional HTML tag. */
function stripFootnotes(text) {
    let out = String(text).replace(/<[^>]+>/g, " ").replace(/\[\d+\]/g, "");
    for (const [pattern, replacement] of LIGATURES) out = out.replace(pattern, replacement);
    return tidy(out).replace(/\s+([,.;:!?])/g, "$1");
}

// --- sources ---------------------------------------------------------------

/** fawazahmed0 editions are `{ quran: [{ chapter, verse, text }] }`. */
function flattenCdnEdition(json, surahs, label) {
    const rows = json.quran ?? json;
    if (rows.length !== TOTAL_AYAT) throw new Error(`${label}: ${rows.length} rows, expected ${TOTAL_AYAT}`);
    const verses = new Array(TOTAL_AYAT);
    for (const row of rows) {
        const surah = surahs[row.chapter - 1];
        if (!surah || row.verse < 1 || row.verse > surah.ayahCount) {
            throw new Error(`${label}: ${row.chapter}:${row.verse} is out of range`);
        }
        verses[surah.startIndex + row.verse - 1] = tidy(row.text);
    }
    const hole = verses.findIndex((verse) => verse === undefined);
    if (hole !== -1) throw new Error(`${label}: no text at flat index ${hole}`);
    return verses;
}

/** Tanzil's `sura|aya|text` text dump, used when the CDN copy is unreachable. */
function parseTanzilPipes(body, surahs) {
    const verses = new Array(TOTAL_AYAT);
    for (const line of body.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) continue;
        const [rawSurah, rawAyah, ...rest] = trimmed.split("|");
        const surahNumber = Number(rawSurah);
        const ayah = Number(rawAyah);
        if (!Number.isInteger(surahNumber) || !Number.isInteger(ayah) || rest.length === 0) continue;
        const surah = surahs[surahNumber - 1];
        if (!surah || ayah < 1 || ayah > surah.ayahCount) continue;
        verses[surah.startIndex + ayah - 1] = tidy(rest.join("|"));
    }
    const hole = verses.findIndex((verse) => verse === undefined);
    if (hole !== -1) throw new Error(`tanzil: no text at flat index ${hole}`);
    return verses;
}

async function fetchArabic(surahs) {
    try {
        const body = await cachedFetch("ara-quranuthmanihaf.json", `${CDN}/ara-quranuthmanihaf.json`);
        return flattenCdnEdition(JSON.parse(body), surahs, "arabic-uthmani");
    } catch (error) {
        console.warn(`arabic: CDN copy unavailable (${error.message}); falling back to Tanzil`);
        const body = await cachedFetch("tanzil-uthmani.txt", TANZIL_DOWNLOAD, {
            method: "POST",
            headers: { "content-type": "application/x-www-form-urlencoded" },
            body: "quranType=uthmani&outType=txt&agree=true",
        });
        return parseTanzilPipes(body, surahs);
    }
}

/** QuranEnc serves one sura per request. Sequential, 150 ms apart, three tries each. */
async function fetchQuranEnc(key, surahs) {
    const verses = new Array(TOTAL_AYAT);
    for (const surah of surahs) {
        const name = `quranenc-${key}-${String(surah.number).padStart(3, "0")}.json`;
        const wasCached = existsSync(join(CACHE, name));
        const body = await cachedFetch(name, `${QURANENC}/${key}/${surah.number}`);
        const rows = JSON.parse(body).result;
        if (!Array.isArray(rows) || rows.length !== surah.ayahCount) {
            throw new Error(`${key}: surah ${surah.number} returned ${rows?.length} ayat, expected ${surah.ayahCount}`);
        }
        for (const row of rows) {
            const ayah = Number(row.aya);
            if (ayah < 1 || ayah > surah.ayahCount) throw new Error(`${key}: ${surah.number}:${row.aya} out of range`);
            const text = stripFootnotes(row.translation);
            if (!text) throw new Error(`${key}: empty translation at ${surah.number}:${ayah}`);
            verses[surah.startIndex + ayah - 1] = text;
        }
        if (!wasCached) await sleep(150);
    }
    const hole = verses.findIndex((verse) => verse === undefined);
    if (hole !== -1) throw new Error(`${key}: no text at flat index ${hole}`);
    return verses;
}

async function quranEncVersions() {
    try {
        const body = await cachedFetch("quranenc-translations-list.json", "https://quranenc.com/api/v1/translations/list");
        const entries = JSON.parse(body).translations ?? [];
        return Object.fromEntries(entries.map((entry) => [entry.key, entry.version]));
    } catch (error) {
        console.warn(`quranenc: could not read the version list (${error.message})`);
        return {};
    }
}

// --- registry --------------------------------------------------------------

function registry(versions) {
    const saheehVersion = versions.english_saheeh ? ` (english_saheeh v${versions.english_saheeh})` : "";
    const ruwwadVersion = versions.english_rwwad ? ` (english_rwwad v${versions.english_rwwad})` : "";
    return {
        version: 2,
        defaultID: "itani",
        translations: [
            {
                id: "itani",
                abbrev: "CLEAR",
                name: "ClearQuran",
                translator: "Talal Itani",
                language: "en",
                year: 2012,
                copyright: "Translation by Talal Itani, ClearQuran.com",
                attribution: "Translation by Talal Itani, ClearQuran.com",
                licence: "CC BY-ND 4.0",
                file: "quran/itani.json",
                isDefault: true,
                bundled: true,
                offline: true,
            },
            {
                id: "saheeh",
                abbrev: "SAHEEH",
                name: "Saheeh International",
                translator: "Saheeh International",
                language: "en",
                year: 1997,
                copyright: "The Qur'an: English Meanings, Saheeh International. Republished with attribution.",
                attribution: `Saheeh International, via QuranEnc.com${saheehVersion}`,
                licence: "Verbatim republication with attribution",
                file: "quran/saheeh.json",
                isDefault: false,
                bundled: true,
                offline: true,
            },
            {
                id: "ruwwad",
                abbrev: "RUWWAD",
                name: "Ruwwad Translation Center",
                translator: "Ruwwad Translation Center, with the Islamic University of Madinah",
                language: "en",
                year: 2022,
                copyright: "Ruwwad Translation Center. Republished with attribution.",
                attribution: `Ruwwad Translation Center, via QuranEnc.com${ruwwadVersion}`,
                licence: "Verbatim republication with attribution",
                file: "quran/ruwwad.json",
                isDefault: false,
                bundled: true,
                offline: true,
            },
            {
                id: "pickthall",
                abbrev: "PICKTHALL",
                name: "The Meaning of the Glorious Koran",
                translator: "Marmaduke Pickthall",
                language: "en",
                year: 1930,
                copyright: "Public domain.",
                attribution: "Marmaduke Pickthall, The Meaning of the Glorious Koran (public domain)",
                licence: "Public domain",
                file: "quran/pickthall.json",
                isDefault: false,
                bundled: true,
                offline: true,
            },
        ],
        arabic: {
            id: "arabic-uthmani",
            name: "Uthmani (Hafs)",
            file: "quran/arabic-uthmani.json",
            copyright: "Quran text from Tanzil.net",
            attribution: "Quran text (Uthmani) from Tanzil.net, licensed CC BY 3.0.",
            licence: "CC BY 3.0",
            offline: true,
        },
    };
}

// --- checks ----------------------------------------------------------------

function checkTranslation(id, verses) {
    if (verses.length !== TOTAL_AYAT) throw new Error(`${id}: ${verses.length} entries, expected ${TOTAL_AYAT}`);
    const empty = verses.findIndex((verse) => !verse || !verse.trim());
    if (empty !== -1) throw new Error(`${id}: empty entry at flat index ${empty}`);
    const arabic = verses.findIndex((verse) => ARABIC.test(verse));
    if (arabic !== -1) throw new Error(`${id}: Arabic script at flat index ${arabic}: ${verses[arabic].slice(0, 80)}`);
}

function checkArabic(verses) {
    if (verses.length !== TOTAL_AYAT) throw new Error(`arabic-uthmani: ${verses.length} entries, expected ${TOTAL_AYAT}`);
    const plain = verses.findIndex((verse) => !verse || !ARABIC.test(verse));
    if (plain !== -1) throw new Error(`arabic-uthmani: no Arabic script at flat index ${plain}`);
}

async function readJSON(path) {
    return JSON.parse(await readFile(path, "utf8"));
}

async function loadSurahs() {
    const surahs = await readJSON(join(OUT, "surahs.json"));
    if (surahs.length !== SURAH_COUNT) throw new Error(`surahs.json has ${surahs.length} entries, expected ${SURAH_COUNT}`);
    let running = 0;
    for (const surah of surahs) {
        if (surah.startIndex !== running) throw new Error(`surah ${surah.number} startIndex ${surah.startIndex} != ${running}`);
        running += surah.ayahCount;
    }
    if (running !== TOTAL_AYAT) throw new Error(`ayah total ${running} != ${TOTAL_AYAT}`);
    if (surahs[1].startIndex + 255 - 1 !== 261) throw new Error("2:255 does not land on global index 261");
    return surahs;
}

const TRANSLATION_FILES = ["itani.json", "saheeh.json", "ruwwad.json", "pickthall.json"];

async function verify() {
    const surahs = await loadSurahs();
    console.log(`surahs.json          ${surahs.length} surahs, ${TOTAL_AYAT} ayat, 2:255 -> global index 261`);

    const arabic = await readJSON(join(OUT, "arabic-uthmani.json"));
    checkArabic(arabic);
    console.log(`arabic-uthmani.json  ${arabic.length} ayat, all Arabic script`);

    for (const file of TRANSLATION_FILES) {
        const verses = await readJSON(join(OUT, file));
        checkTranslation(file, verses);
        console.log(`${file.padEnd(20)} ${verses.length} verses, no Arabic script, none empty`);
    }

    const parsed = await readJSON(join(OUT, "translations.json"));
    const defaults = parsed.translations.filter((entry) => entry.isDefault);
    if (defaults.length !== 1) throw new Error(`translations.json has ${defaults.length} defaults, expected exactly 1`);
    if (defaults[0].id !== parsed.defaultID) throw new Error("defaultID does not match the isDefault entry");
    const abbrevs = parsed.translations.map((entry) => entry.abbrev);
    if (new Set(abbrevs).size !== abbrevs.length) throw new Error("duplicate abbrev in translations.json");
    for (const entry of parsed.translations) {
        for (const field of ["id", "abbrev", "name", "translator", "copyright", "attribution", "licence", "file"]) {
            if (!entry[field]) throw new Error(`translations.json: ${entry.id} is missing ${field}`);
        }
        if (!existsSync(join(ROOT, "Content", entry.file))) throw new Error(`translations.json: missing ${entry.file}`);
    }
    console.log(`translations.json    ${parsed.translations.length} translations (${abbrevs.join(", ")}), default ${parsed.defaultID}`);
}

// --- sync ------------------------------------------------------------------

async function copyFromInbox() {
    const names = (await readdir(INBOX)).filter((name) => name.endsWith(".json"));
    const wanted = new Set(["arabic-uthmani.json", ...TRANSLATION_FILES]);
    const copied = [];
    for (const name of names) {
        if (!wanted.has(name)) continue;
        await copyFile(join(INBOX, name), join(OUT, name));
        copied.push(name);
    }
    return copied;
}

async function download(surahs) {
    const versions = await quranEncVersions();

    const arabic = await fetchArabic(surahs);
    checkArabic(arabic);
    await writeFile(join(OUT, "arabic-uthmani.json"), `${JSON.stringify(arabic)}\n`);
    console.log(`arabic-uthmani.json  ${arabic.length} ayat`);

    const pickthall = flattenCdnEdition(
        JSON.parse(await cachedFetch("eng-mohammedmarmadu.json", `${CDN}/eng-mohammedmarmadu.json`)),
        surahs,
        "pickthall",
    );
    checkTranslation("pickthall", pickthall);
    await writeFile(join(OUT, "pickthall.json"), `${JSON.stringify(pickthall)}\n`);
    console.log(`pickthall.json       ${pickthall.length} verses`);

    for (const [id, key] of [["saheeh", "english_saheeh"], ["ruwwad", "english_rwwad"]]) {
        const verses = await fetchQuranEnc(key, surahs);
        checkTranslation(id, verses);
        await writeFile(join(OUT, `${id}.json`), `${JSON.stringify(verses)}\n`);
        console.log(`${`${id}.json`.padEnd(20)} ${verses.length} verses (${key} v${versions[key] ?? "?"})`);
    }

    return versions;
}

async function main() {
    if (VERIFY_ONLY) {
        await verify();
        return;
    }

    await mkdir(OUT, { recursive: true });
    const surahs = await loadSurahs();

    let versions = {};
    if (!FORCE_FETCH && existsSync(INBOX)) {
        const copied = await copyFromInbox();
        console.log(`copied ${copied.length} file(s) from Tools/content-gen/out/quran: ${copied.join(", ")}`);
        versions = await quranEncVersions();
        const missing = ["arabic-uthmani.json", ...TRANSLATION_FILES].filter((name) => !existsSync(join(OUT, name)));
        if (missing.length) {
            console.log(`downloading what out/quran did not provide: ${missing.join(", ")}`);
            versions = await download(surahs);
        }
    } else {
        versions = await download(surahs);
    }

    await writeFile(join(OUT, "translations.json"), `${JSON.stringify(registry(versions), null, 2)}\n`);
    console.log("translations.json    rewritten");

    console.log("");
    await verify();
}

main().catch((error) => {
    console.error(error.message);
    process.exit(1);
});
