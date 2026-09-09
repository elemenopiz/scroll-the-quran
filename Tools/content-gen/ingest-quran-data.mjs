#!/usr/bin/env node
// Rebuilds the bundled Quran data from its upstream sources.
//
//   node Tools/content-gen/ingest-quran-data.mjs [--offline]
//
// Writes:
//   Content/quran/surahs.json       114 surahs from Tanzil quran-data.xml (CC BY 3.0)
//   Content/quran/itani.json        6,236 verse strings, Talal Itani / ClearQuran (CC BY-ND 4.0)
//
// Content/ is generated: edit this script, not its output. Every ayah is checked for
// Arabic script before it is written — v1 ships English only.
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { SURAH_NAMES } from "./surah-names.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CACHE = join(ROOT, "Tools", "content-gen", "work");
const OUT = join(ROOT, "Content", "quran");

const SOURCES = {
    "quran-data.xml": "https://tanzil.net/res/text/metadata/quran-data.xml",
    "eng-talalitani.json": "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/eng-talalitani.json",
};

const ARABIC = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/;
const TOTAL_AYAT = 6236;

async function fetchSource(name) {
    await mkdir(CACHE, { recursive: true });
    const cached = join(CACHE, name);
    if (existsSync(cached)) return readFile(cached, "utf8");
    if (process.argv.includes("--offline")) throw new Error(`missing cached source ${cached} and --offline was passed`);
    const response = await fetch(SOURCES[name]);
    if (!response.ok) throw new Error(`GET ${SOURCES[name]} -> ${response.status}`);
    const body = await response.text();
    await writeFile(cached, body);
    return body;
}

function parseSuras(xml) {
    return [...xml.matchAll(/<sura\s+([^/>]+)\/>/g)].map((match) => {
        const attrs = Object.fromEntries([...match[1].matchAll(/(\w+)="([^"]*)"/g)].map((a) => [a[1], a[2]]));
        return {
            index: Number(attrs.index),
            ayas: Number(attrs.ayas),
            start: Number(attrs.start),
            ename: attrs.ename,
            type: attrs.type,
            order: Number(attrs.order),
            rukus: Number(attrs.rukus),
        };
    });
}

function parseJuzStarts(xml) {
    return [...xml.matchAll(/<juz\s+([^/>]+)\/>/g)].map((match) => {
        const attrs = Object.fromEntries([...match[1].matchAll(/(\w+)="([^"]*)"/g)].map((a) => [a[1], a[2]]));
        return { index: Number(attrs.index), sura: Number(attrs.sura), aya: Number(attrs.aya) };
    });
}

/// Every juz a surah appears in, ascending.
function juzListFor(sura, juzStarts, suras) {
    const globalStart = sura.start;
    const globalEnd = sura.start + sura.ayas - 1;
    const startOf = (j) => suras[j.sura - 1].start + j.aya - 1;
    const juz = [];
    for (let i = 0; i < juzStarts.length; i += 1) {
        const from = startOf(juzStarts[i]);
        const to = i + 1 < juzStarts.length ? startOf(juzStarts[i + 1]) - 1 : TOTAL_AYAT - 1;
        if (from <= globalEnd && to >= globalStart) juz.push(juzStarts[i].index);
    }
    return juz;
}

async function main() {
    const xml = await fetchSource("quran-data.xml");
    const suras = parseSuras(xml);
    const juzStarts = parseJuzStarts(xml);
    if (suras.length !== 114) throw new Error(`expected 114 suras, got ${suras.length}`);
    if (juzStarts.length !== 30) throw new Error(`expected 30 juz, got ${juzStarts.length}`);

    const surahs = suras.map((sura) => ({
        number: sura.index,
        name: SURAH_NAMES[sura.index - 1],
        meaning: sura.ename,
        ayahCount: sura.ayas,
        revelation: sura.type,
        // Zero-based offset into the flat 6,236-verse arrays.
        // Global index of an ayah = startIndex + ayah - 1, so 2:255 is 261.
        startIndex: sura.start,
        revelationOrder: sura.order,
        rukus: sura.rukus,
        juz: juzListFor(sura, juzStarts, suras),
    }));

    let running = 0;
    for (const surah of surahs) {
        if (surah.startIndex !== running) throw new Error(`surah ${surah.number} startIndex ${surah.startIndex} != ${running}`);
        running += surah.ayahCount;
        if (ARABIC.test(surah.name) || ARABIC.test(surah.meaning)) throw new Error(`Arabic script in surah ${surah.number}`);
    }
    if (running !== TOTAL_AYAT) throw new Error(`ayah total ${running} != ${TOTAL_AYAT}`);

    const raw = JSON.parse(await fetchSource("eng-talalitani.json"));
    const rows = raw.quran ?? raw;
    rows.sort((a, b) => a.chapter - b.chapter || a.verse - b.verse);
    if (rows.length !== TOTAL_AYAT) throw new Error(`translation has ${rows.length} rows, expected ${TOTAL_AYAT}`);

    const verses = rows.map((row, i) => {
        const surah = surahs[row.chapter - 1];
        if (!surah || surah.startIndex + row.verse - 1 !== i) {
            throw new Error(`row ${i} is ${row.chapter}:${row.verse}, which is out of order`);
        }
        const text = String(row.text).replace(/\s+/g, " ").trim();
        if (ARABIC.test(text)) throw new Error(`Arabic script at ${row.chapter}:${row.verse}`);
        if (!text) throw new Error(`empty text at ${row.chapter}:${row.verse}`);
        return text;
    });

    await mkdir(OUT, { recursive: true });
    await writeFile(join(OUT, "surahs.json"), `${JSON.stringify(surahs, null, 2)}\n`);
    await writeFile(join(OUT, "itani.json"), `${JSON.stringify(verses, null, 0)}\n`);

    console.log(`surahs.json  114 surahs, ${running} ayat, juz 1-${juzStarts.length}`);
    console.log(`itani.json   ${verses.length} verses, 2:255 at index ${surahs[1].startIndex + 254}`);
}

main().catch((error) => {
    console.error(error.message);
    process.exit(1);
});
