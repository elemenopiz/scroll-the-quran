// The translation registry written to out/quran/translations.json.
// Copyright / attribution strings are shown verbatim in the app's Translation
// sheet, so they live here as data and are asserted by --verify.

/**
 * @param {{saheehVersion?:string, ruwwadVersion?:string}} versions
 *   versions reported by the QuranEnc /translations/list endpoint at fetch time
 * @returns {object[]}
 */
export function buildRegistry(versions = {}) {
  const saheehVersion = versions.saheehVersion ?? "unknown";
  const ruwwadVersion = versions.ruwwadVersion ?? "unknown";
  return [
    {
      id: "itani",
      abbrev: "CLEAR",
      name: "ClearQuran",
      translator: "Talal Itani",
      language: "en",
      copyright: "© Talal Itani / ClearQuran.com. Licensed CC BY-ND 4.0.",
      attribution: "Translation by Talal Itani, ClearQuran.com",
      license: "CC BY-ND 4.0",
      file: "itani.json",
      isDefault: true,
      offline: true,
    },
    {
      id: "saheeh",
      abbrev: "SAHEEH",
      name: "Saheeh International",
      translator: "Saheeh International",
      language: "en",
      copyright: `© Saheeh International. Distributed free of charge by QuranEnc.com (Encyclopedia of the Noble Qur'an), text version ${saheehVersion}.`,
      attribution: "Saheeh International, via QuranEnc.com",
      license:
        "Free redistribution permitted by the publisher via QuranEnc.com; no SPDX licence stated.",
      file: "saheeh.json",
      isDefault: false,
      offline: true,
    },
    {
      id: "ruwwad",
      abbrev: "RUWWAD",
      name: "Ruwwad Translation Center",
      translator: "Ruwwad Translation Center",
      language: "en",
      copyright: `© Ruwwad Translation Center, in cooperation with the Rabwah Dawah Association and IslamHouse.com. Distributed free of charge by QuranEnc.com, text version ${ruwwadVersion}.`,
      attribution: "Ruwwad Translation Center, via QuranEnc.com",
      license:
        "Free redistribution permitted by the publisher via QuranEnc.com; no SPDX licence stated.",
      file: "ruwwad.json",
      isDefault: false,
      offline: true,
    },
    {
      id: "pickthall",
      abbrev: "PICKTHALL",
      name: "The Meaning of the Glorious Koran",
      translator: "Marmaduke Pickthall",
      language: "en",
      copyright: "Marmaduke Pickthall, The Meaning of the Glorious Koran (1930). Public domain.",
      attribution: "Marmaduke Pickthall, public domain",
      license: "Public domain",
      file: "pickthall.json",
      isDefault: false,
      offline: true,
    },
  ];
}

/** Registry field names every entry must carry, in order. */
export const REGISTRY_FIELDS = [
  "id",
  "abbrev",
  "name",
  "translator",
  "language",
  "copyright",
  "attribution",
  "license",
  "file",
  "isDefault",
  "offline",
];

/** Strings the brief pins exactly; --verify asserts them. */
export const REQUIRED_STRINGS = {
  itani: { abbrev: "CLEAR", attribution: "Translation by Talal Itani, ClearQuran.com", license: "CC BY-ND 4.0" },
  saheeh: { abbrev: "SAHEEH", attribution: "Saheeh International, via QuranEnc.com" },
  ruwwad: { abbrev: "RUWWAD", attribution: "Ruwwad Translation Center, via QuranEnc.com" },
  pickthall: { abbrev: "PICKTHALL", license: "Public domain" },
};
