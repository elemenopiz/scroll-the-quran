# App Store metadata — Scroll the Quran

Everything App Store Connect asks for, in the order it asks for it, ready to paste.
Character limits are noted per field and every string below is inside its limit (counts
were checked, not estimated).

Version: **1.0.0** (build **1**) — `Config/Release.xcconfig`, `MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION`.

| Identifier | Value |
|---|---|
| App bundle id | `com.scrollthequran.app` |
| Widget bundle id | `com.scrollthequran.app.widget` |
| App Group | `group.com.scrollthequran` |
| URL scheme | `scrollthequran://` (e.g. `scrollthequran://verse/2/255`) |
| SKU | `SCROLLQURAN001` |
| Primary language | English (U.S.) |

---

## 1. App information

### Name (30 char limit) — 16 used

```
Scroll the Quran
```

### Subtitle (30 char limit) — 19 used

```
One verse at a time
```

### Category

- **Primary:** Books
- **Secondary:** Reference

Books is primary because the app's centre of gravity is reading a single continuous
text; Reference is secondary because Deep Study and the search/library surfaces are
look-up tools rather than a reading experience.

### Content rights

The app contains third-party content that is licensed for redistribution (Quran text,
four English translations, two Arabic typefaces). Answer **"Yes, it contains, shows, or
accesses third-party content"** and be ready to point at
`Tools/content-gen/ATTRIBUTION.md`, which records the source, URL, licence, licence text
and fetch date for every bundled artefact. All four translations and both fonts are
either CC-licensed, public domain, or redistributed with the publisher's permission; the
app ships them unmodified where the licence requires it (Tanzil CC BY 3.0 verbatim,
Itani CC BY-ND 4.0 unmodified, the KFGQPC Hafs font unsubsetted).

### Age rating — **4+**

Answer every content question **None**. The full questionnaire, with the answer and the
reason:

| Question | Answer | Why |
|---|---|---|
| Cartoon or Fantasy Violence | None | No violence depicted anywhere in the UI. |
| Realistic Violence | None | — |
| Prolonged Graphic or Sadistic Realistic Violence | None | — |
| Profanity or Crude Humor | None | Scripture and scholarly commentary only. |
| Mature/Suggestive Themes | None | — |
| Horror/Fear Themes | None | — |
| Medical/Treatment Information | None | The app gives no health advice. |
| Alcohol, Tobacco, or Drug Use or References | None | Where scripture mentions intoxicants the treatment is scriptural, not a depiction or reference encouraging use. |
| Simulated Gambling | None | — |
| Sexual Content or Nudity | None | — |
| Graphic Sexual Content and Nudity | None | — |
| Contests | None | — |
| Unrestricted Web Access | **No** | The app has no in-app browser. The only outbound links (a charity's own site on the Community tab, and the Terms/Privacy links on the paywall) open in Safari through `openURL`, to a fixed set of URLs shipped in the bundle. |
| Gambling and Contests | None | — |
| User Generated Content / messaging | **No** | Notes are private, stored on device, and never shared with or visible to another user. There is no chat, no feed, no profile, no uploads. |
| Made for Kids | **No** | Not a Kids Category app. |
| In-App Purchases present | **Yes** | Auto-renewable subscriptions (section 4). Declaring IAP does not raise the rating. |

There is no age-rating category for religious content, and none is required: the app
presents a religious scripture and scholarly commentary about it, which Apple rates on
the content questions above. **4+** is the correct rating.

### Copyright

```
2026 Scroll the Quran
```

---

## 2. Version information (the "1.0 Prepare for Submission" page)

### Promotional text (170 char limit, editable without a new build) — 149 used

```
Start where you are. One ayah fills the screen, the Arabic above the English, and a tap opens the story behind it. Your streak is waiting.
```

### Description (4000 char limit)

```
Scroll the Quran turns the Book into something you actually open every day.

One verse at a time. Each ayah gets the whole screen — the Uthmani Arabic above, a clear
English translation below, nothing else competing for your attention. Swipe up for the
next verse. That is the entire interaction, and it is why people keep reading.

GO DEEPER ON ANY PASSAGE
Tap a verse and Deep Study opens: what the passage means, the historical moment it
arrived in, the key Arabic terms with their glosses, what life looked like in the
Prophet's time, the theological weight of it, where else in the Quran the same thread
runs, and how to act on it this week. Deep Study is written for 107 surahs and counting.

FOUR ENGLISH TRANSLATIONS
Read in ClearQuran (Talal Itani), Saheeh International, Ruwwad, or Pickthall, and switch
between them mid-verse. Every translation carries its translator and licence, shown in
full inside the app.

BUILD THE HABIT
A daily streak that counts real reading, not app opens. A week-at-a-glance row on Home.
Reading plans — the whole Quran in 30 days, Juz Amma, Al-Kahf on Fridays, Ayat al-Kursi,
or a themed path through patience, gratitude and mercy. And a Home Screen widget that
puts a verse where you will actually see it.

DISCOVER BY THEME
Fifteen themes — patience in trials, gratitude, the mercy of God, trust, forgiveness,
prayer, charity, family, justice, knowledge, the hereafter — each a curated path through
the passages that speak to it.

KEEP WHAT MOVES YOU
Save verses to your library, write private notes, and share a verse as a card worth
posting. Notes never leave your device.

READ TOGETHER, GIVE TOGETHER
The Community tab puts a share of every subscription behind a charity the community
votes for, and tells you where it went.

WORKS ANYWHERE
Every verse, translation, study note and plan is bundled in the app. No account needed,
no network required, nothing to sync. Open it on a plane, in a tunnel, at 3am.

ABOUT THE STUDY NOTES
The Deep Study commentary in this app is AI-assisted: it was drafted with AI drawing on
the classical works of tafsir — Ibn Kathir, al-Tabari, al-Qurtubi and al-Sa'di — and
reviewed before it shipped. It is study material, not a fatwa and not a substitute for a
qualified scholar. Where scholars differ, we say so. The Quran text and the translations
themselves are not AI-generated: the Arabic is the Tanzil Project's Uthmani text (CC BY
3.0) and the English is the work of Talal Itani (ClearQuran), Saheeh International,
Ruwwad Translation Center and Marmaduke Pickthall, reproduced as their licences require.

PREMIUM
Scroll the Quran is free to read. Premium unlocks Deep Study on every passage, all
reading plans and every translation.
- Yearly $29.99 with a 7-day free trial
- Monthly $4.99
Payment is charged to your Apple Account at confirmation of purchase. The subscription
renews automatically unless you turn off auto-renew at least 24 hours before the end of
the current period; manage or cancel it in Settings > Apple Account > Subscriptions. Any
unused portion of a free trial is forfeited when you buy a subscription.

Terms: https://scrollthequran.app/terms
Privacy: https://scrollthequran.app/privacy
```

> The Premium paragraph is required by App Review guideline 3.1.2 — price, period,
> renewal terms and links to Terms and Privacy Policy must appear in the description as
> well as on the paywall itself (they already do, via `PaywallLegalLinks`).

### Keywords (100 char limit, comma-separated, no spaces) — 99 used

```
koran,islam,muslim,tafsir,ayah,surah,arabic,verse,daily,study,prayer,ramadan,dua,deen,iman,memorize
```

"quran" is deliberately absent: terms in the app name are already indexed, so spending
six characters on it would be waste.

### Support URL (required)

```
https://scrollthequran.app/support
```

> **Placeholder — must resolve before submission.** App Review opens this URL. A page
> that 404s is a metadata rejection. It needs, at minimum, a way to contact a human and
> an answer to "how do I cancel".

### Marketing URL (optional)

```
https://scrollthequran.app
```

### Privacy Policy URL (required)

```
https://scrollthequran.app/privacy
```

Must serve the text in section 3 and must be reachable without an account.

### What's New in This Version

```
First release.
```

---

## 3. Privacy

### 3.1 App Privacy answers (App Store Connect → App Privacy)

**"Do you or your third-party partners collect data from this app?" → No.**

That answer is only defensible because it is literally true, and it must stay consistent
with `App/PrivacyInfo.xcprivacy`, which declares `NSPrivacyTracking = false`, an empty
`NSPrivacyTrackingDomains`, and an empty `NSPrivacyCollectedDataTypes`. The evidence:

- The app makes **zero network calls** (CLAUDE.md rule 9). Every verse, translation,
  study note, plan, theme and charity blurb is bundled in `Content/`.
- No analytics SDK, no crash reporter, no attribution SDK, no ad network. The only
  Apple framework that talks to a server is StoreKit, and Apple's own purchase and
  subscription data is outside the App Privacy questionnaire's scope (you do not declare
  data Apple collects to run the App Store).
- Sign in with Apple is **optional** — the app is fully usable without it — and its
  result is stored on device only. Nothing is transmitted to a server we control,
  because there is no server we control.
- Streak, reading progress, library, notes, plan progress and preferences live as JSON
  in the App Group container `group.com.scrollthequran`, shared between the app and its
  widget, and nowhere else. They ride along in the user's own iCloud/iTunes device
  backup, which is not "collection" by the app.

If App Review pushes back on Sign in with Apple: the answer is that an account
identifier stored only on the user's device is not collected data. If you later add any
server, this answer changes and the privacy manifest changes with it.

### 3.2 Privacy policy — full text

Paste this at `https://scrollthequran.app/privacy`. It is deliberately short because
there is very little to say.

```
PRIVACY POLICY — SCROLL THE QURAN
Last updated: 2026-09-12

THE SHORT VERSION
Scroll the Quran does not collect your data. The app has no servers, no analytics and no
advertising, and it makes no network requests of its own. Everything you do in the app
stays on your device.

WHAT THE APP STORES, AND WHERE
The app saves the following on your device, inside a shared container that the app and
its Home Screen widget can both read (an "App Group", identified as
group.com.scrollthequran):
  - your reading progress and which verses you have read
  - your daily streak and reading history
  - verses you have saved to your library
  - notes you write on verses
  - your progress through reading plans
  - your preferences, such as your chosen translation
The app also uses the standard iOS preferences store for small flags — whether you have
finished onboarding, whether you have seen a one-time hint, and your purchase state.

None of this is transmitted anywhere. We cannot see it. It is included in your device
backup if you back your device up, and it is deleted when you delete the app.

NETWORK
The app makes no network requests. The Quran text, all four English translations, all
study notes, reading plans and imagery are bundled inside the app when you download it,
which is why the app works with no connection at all.

Two things in the app can open your web browser, and only when you tap them: the Terms
and Privacy links on the subscription screen, and the "learn more" link on a charity's
card on the Community tab, which opens that organisation's own website. Those sites have
their own privacy policies and we have no control over them.

SIGN IN WITH APPLE
Signing in is optional and the app works fully without it. If you do sign in, Apple gives
the app an identifier for you, which is stored on your device and used only to label your
account inside the app. It is not sent to us, because there is nowhere to send it. If you
chose to hide your email address, Apple's relay never gives us your real address. You can
revoke the app's access at any time in Settings > Apple Account > Sign in with Apple.

PURCHASES
Subscriptions are sold and processed by Apple through the App Store using StoreKit. We
never see or receive your payment details. The app asks StoreKit whether a subscription
is currently active, and that answer is what unlocks Premium; the answer is kept on your
device. Apple's handling of your purchase is governed by Apple's own privacy policy.

ANALYTICS, TRACKING AND ADVERTISING
There are none. The app contains no analytics SDK, no crash-reporting SDK, no advertising
identifier and no tracking of any kind. We do not build a profile of you, we do not share
anything with data brokers, and the App Tracking Transparency prompt is never shown
because there is nothing to track. Apple may give us anonymous aggregate App Store
statistics — downloads by country, for example — which are produced by Apple and are not
linked to you.

CHILDREN
The app is rated 4+ and collects nothing from anyone, including children. It is not
directed at children under 13 in the sense of COPPA, and since no data is collected there
is no children's data to protect.

YOUR RIGHTS
Because we hold no data about you, there is nothing for us to show you, correct, export
or delete. To erase everything the app has stored, delete the app; to erase only your
saved content while keeping the app, use the reset control in Settings inside the app.

CHANGES
If this policy changes, the "last updated" date above changes with it. If the app ever
starts collecting data, it will say so here and in the app before it does.

CONTACT
support@scrollthequran.app
```

> Replace `support@scrollthequran.app` with the address you will actually monitor, and
> keep the "last updated" date honest.

### 3.3 Privacy manifest

`App/PrivacyInfo.xcprivacy` ships in the app's Resources build phase (XcodeGen puts it
there; `Tools/release/archive.sh --preflight` asserts it). It declares one required-reason
API — `NSPrivacyAccessedAPICategoryUserDefaults`, reason **CA92.1** — and the comment in
the file records the grep that proved the other four categories have no call sites. The
App Privacy answers above must never drift from it.

---

## 4. In-app purchases

Three auto-renewable subscriptions in one group. The identifiers below are the
authority in `Packages/ScrollKit/Sources/Commerce/ProductID.swift` and the local test
configuration `Config/ScrollTheQuran.storekit`; nothing else in the app spells a product
identifier out. **The strings you type into App Store Connect must match these exactly.**

### Subscription group

| Field | Value |
|---|---|
| Reference Name (internal, 64 char) | `Premium` |
| Display Name (customer-facing, 30 char) | `Premium` |
| Local group id (StoreKit config / `ProductID.subscriptionGroupID`) | `21500001` |

App Store Connect assigns its own numeric group id when you create the group; the app
never reads it at runtime for purchasing, so the two do not have to match. Keep
`21500001` in the `.storekit` file so local testing keeps working.

### 4.1 Premium Yearly — headline plan

| Field | Value |
|---|---|
| Product ID | `com.scrollthequran.yearly` |
| Reference Name (internal) | `Premium Yearly` |
| Display Name (30 char limit) — 14 used | `Premium Yearly` |
| Description (45 char limit) — 42 used | `Deep Study, every plan, every translation.` |
| Duration | 1 year |
| Price (USA) | **$29.99** (Tier equivalent; set USD 29.99 and let ASC generate the rest) |
| Subscription level in group | 1 |
| Family Sharing | Off |
| Introductory Offer | **7 days free**, Free trial, one per customer, new subscribers |

### 4.2 Premium Monthly — the alternative on "View all plans"

| Field | Value |
|---|---|
| Product ID | `com.scrollthequran.monthly` |
| Reference Name (internal) | `Premium Monthly` |
| Display Name (30 char limit) — 15 used | `Premium Monthly` |
| Description (45 char limit) — 42 used | `Deep Study, every plan, every translation.` |
| Duration | 1 month |
| Price (USA) | **$4.99** |
| Subscription level in group | 2 |
| Family Sharing | Off |
| Introductory Offer | **None** |

### 4.3 Premium Yearly (Gift) — the one-time offer after the paywall is dismissed

| Field | Value |
|---|---|
| Product ID | `com.scrollthequran.yearly.gift` |
| Reference Name (internal) | `Premium Yearly Gift` |
| Display Name (30 char limit) — 21 used | `Premium Yearly (Gift)` |
| Description (45 char limit) — 39 used | `A year of Premium at 33% off. One time.` |
| Duration | 1 year |
| Price (USA) | **$19.99** (33% below the $29.99 yearly) |
| Subscription level in group | 1 |
| Family Sharing | Off |
| Introductory Offer | **3 days free**, Free trial, one per customer, new subscribers |

> **Review risk, flagged in `audit-findings.md`:** the gift is a separate, cheaper SKU at
> the *same* subscription level as the yearly plan rather than a promotional offer on it.
> That is legal, but it means a customer can see two prices for the same year of the same
> thing, and App Review sometimes asks about it. The honest answer, if asked: it is a
> one-time welcome offer shown once, to a user who declined the standard paywall, and it
> is disclosed as such in the UI ("One Time Offer", "You will never see this again").

### Shared IAP review metadata

Each subscription needs a **review screenshot** (any size; a paywall capture is fine) and
**review notes**. Use:

```
Reachable from a cold start: the onboarding flow ends on the paywall (Premium Yearly,
7-day trial) and "View all plans" on that screen opens the sheet with Premium Monthly.
Dismissing the paywall with the X shows the gift offer (Premium Yearly (Gift)); tap the
envelope to reveal it. No account or login is needed to reach any of them.
```

Screenshots to attach: `docs/store/screenshots/` does not include the paywall (it is not
a marketing screenshot), so capture them ad hoc with:

```
Tools/verify.sh --snap paywall-trial paywall-plans gift-open
```

which writes them under `.build/snapshots/`.

---

## 5. App Review Information

### Sign-in

**"Does your app require a sign-in?" → No.**

### Notes to App Review

```
Scroll the Quran is a Quran reading app. It is fully offline: every verse, translation,
study note, reading plan and image is bundled in the app binary. The app makes no
network requests of its own, so there is nothing to configure and no test server.

NO LOGIN IS REQUIRED
There is no account system. Sign in with Apple appears once during onboarding and is
optional — tap "Skip" (or anywhere outside it) and the app works identically. Please do
not treat the sign-in screen as a gate; nothing behind it is locked by it.

HOW TO REACH EVERY SCREEN
Launch the app fresh (delete and reinstall to see onboarding again):
  1. Onboarding — hook screen, then the optional Sign in with Apple screen, then four
     value slides, then a reviews screen. "Continue" moves forward throughout.
  2. Paywall — appears at the end of onboarding. Premium Yearly with a 7-day free trial
     is preselected. "View all plans" opens the sheet with the monthly plan. "Restore
     Purchases" is on this screen. Terms and Privacy links are at the bottom.
  3. Gift offer — close the paywall with the X in the corner. A sealed envelope appears;
     tap anywhere to reveal the one-time discounted yearly offer. Close it the same way.
  4. Main app — four tabs along the bottom:
     - The Quran: the surah list. Tap any surah to open the reader.
     - Home: your streak, today's reading, reading plans, your saved library, and
       Settings (gear, top right) which holds the translation picker, the reset control
       and the content attributions.
     - Discover: themed verse cards. Tap a card, then "Go deeper" to open Deep Study.
     - Community: the charities the community can vote for, and where giving went.
  5. Reader: swipe up and down to move between verses. The toolbar has the translation
     picker, notes, share and the surah picker. Deep Study for the current passage opens
     from the verse's "Go deeper" affordance.

TESTING THE PAYWALL
Use a sandbox Apple Account (App Store Connect > Users and Access > Sandbox Testers) and
sign into it on the device under Settings > App Store > Sandbox Account. Then:
  - Tap "Start FREE trial" on the paywall to buy Premium Yearly with its 7-day trial.
  - "View all plans" > Premium Monthly to buy the monthly plan.
  - Close the paywall to reach the gift offer and buy Premium Yearly (Gift).
  - "Restore Purchases" on the paywall restores an existing subscription.
Premium unlocks the Deep Study sections, all reading plans and the alternate
translations. Nothing else in the app is behind the paywall — reading the Quran is free.

THE COMMUNITY TAB
No money moves through the app there. The tab lists charitable organisations, lets the
user cast a non-binding vote for which one a share of subscription revenue goes to, and
links out to each organisation's own website in Safari. There is no donation flow, no
collection of funds, and no user-to-user content of any kind.

AI-ASSISTED STUDY NOTES
The "Deep Study" commentary was drafted with AI assistance, working from the classical
works of tafsir (Ibn Kathir, al-Tabari, al-Qurtubi, al-Sa'di), and reviewed before
shipping. The app discloses this in its App Store description and in Settings. The Quran
text and the four English translations are NOT AI-generated — they are licensed source
texts (Tanzil Project, CC BY 3.0; Talal Itani / ClearQuran, CC BY-ND 4.0; Saheeh
International and Ruwwad via QuranEnc.com; Pickthall, public domain), reproduced
unmodified where their licences require it. Full licence ledger on request.

CONTENT RIGHTS
Every bundled text, translation and typeface is licensed for redistribution. We hold a
per-artefact record of source, URL, licence text and fetch date and can supply it
immediately if needed.
```

### Contact information

Provide a first name, last name, phone number and an email address that is monitored
during review. Apple will use it before rejecting anything ambiguous.

### Attachment

Optional. If Deep Study's sourcing is likely to be questioned, attach
`Tools/content-gen/ATTRIBUTION.md` as a PDF.

---

## 6. Export compliance

`App/Info.plist` sets:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

so App Store Connect will **not** ask the encryption questions on upload. That answer is
correct: the app uses no encryption of its own, and makes no HTTPS calls at all (it makes
no calls). Nothing else needs filing — no CCATS, no self-classification report, no annual
report.

`Tools/release/archive.sh --preflight` asserts this key is present and false, so it
cannot silently regress.

---

## 7. The App Store Connect click-path

Do these in order. Steps 1–3 can be done before the build is ready; step 6 needs the
build uploaded.

### Step 0 — Agreements (blocks everything else)

1. App Store Connect → **Business** (formerly Agreements, Tax, and Banking).
2. Accept the **Paid Applications Agreement**. Free apps only need the free agreement,
   but this app sells subscriptions, so the paid agreement is mandatory.
3. Add a **Bank Account** and complete **Tax Forms** for the US (and any other region you
   want to sell in). Status must read *Active*. Until it does, in-app purchases cannot be
   submitted and will show as "Missing Metadata" forever.

### Step 1 — Identifiers (developer.apple.com, not App Store Connect)

1. **Certificates, Identifiers & Profiles → Identifiers → App IDs → +**.
2. Create `com.scrollthequran.app` (explicit, not wildcard). Enable capabilities:
   **App Groups**, **Sign in with Apple**, **In-App Purchase** (on by default).
3. Create `com.scrollthequran.app.widget` (explicit). Enable **App Groups**.
4. **Identifiers → App Groups → +**: create `group.com.scrollthequran`.
5. Go back into both App IDs, edit **App Groups**, and tick `group.com.scrollthequran`
   on each. The app and the widget share their JSON state through this container; if the
   widget is missing it, the widget ships blank.

### Step 2 — Create the app record

1. App Store Connect → **Apps → + → New App**.
2. Platform **iOS**; Name **Scroll the Quran**; Primary Language **English (U.S.)**;
   Bundle ID **`com.scrollthequran.app`** (pick the App ID from step 1 — if it is not in
   the list, the App ID was not created or is a wildcard); SKU **`SCROLLQURAN001`**;
   Full Access.
3. The name is reserved the moment you create the record. If "Scroll the Quran" is taken,
   stop and settle the name before doing anything else — every string in this document
   assumes it.

### Step 3 — Subscription group and the three products

1. App record → **Monetization → Subscriptions → Create** a subscription group.
   - Reference Name: `Premium`
   - Add a localization (English U.S.) with Display Name `Premium` and an App Name
     override of `Scroll the Quran` if prompted.
2. Inside the group, **Create** each of the three subscriptions from section 4, in this
   order (the first one you create defines the group's level 1):
   1. `com.scrollthequran.yearly` — level 1
   2. `com.scrollthequran.yearly.gift` — level 1 (same level as the yearly)
   3. `com.scrollthequran.monthly` — level 2
3. For each product, fill in: Reference Name, Duration, **Subscription Prices** (Add
   Subscription Price → USA → the price from section 4 → let ASC generate other regions),
   a **Localization** (English U.S.) with the Display Name and Description from section 4,
   a **Review screenshot**, and **Review notes**.
4. Add the introductory offers — **Subscription Prices → Introductory Offers → Set Up
   Introductory Offer**:
   - `com.scrollthequran.yearly`: All countries, no end date, **Free**, **1 week**.
   - `com.scrollthequran.yearly.gift`: All countries, no end date, **Free**, **3 days**.
   - `com.scrollthequran.monthly`: none.
   The durations must match `Config/ScrollTheQuran.storekit` (`P1W` and `P3D`) or the
   paywall's trial copy will lie about what the user gets.
5. Each product's status should reach **Ready to Submit**. Anything stuck on "Missing
   Metadata" is missing a price, a localization, a screenshot or the step-0 agreement.

### Step 4 — App Privacy

1. App record → **App Privacy → Get Started**.
2. **"Do you or your third-party partners collect data from this app?" → No.**
3. Publish. Confirm the answers still match `App/PrivacyInfo.xcprivacy` (section 3.3) —
   a mismatch between the manifest in the binary and these answers is a rejection.

### Step 5 — Version metadata

1. App record → **iOS App → 1.0 Prepare for Submission**.
2. Paste from section 2: Promotional Text, Description, Keywords, Support URL, Marketing
   URL.
3. Upload screenshots: **6.9" Display** and **6.5" Display** from
   `docs/store/screenshots/6.9/` and `docs/store/screenshots/6.5/`, in filename order
   (01…05). See `docs/store/screenshots.md`.
4. **General → App Information**: Primary Category **Books**, Secondary **Reference**;
   Content Rights (section 1); Age Rating → answer the questionnaire per section 1 and
   confirm it lands on **4+**.
5. Set the **Privacy Policy URL**.
6. **App Review Information**: sign-in required **No**; paste the review notes from
   section 5; fill in contact details.
7. **Version Release**: Manually release this version (safer for a 1.0 — you decide when
   it goes live).

### Step 6 — Build, upload, attach

1. `Tools/release/archive.sh` — needs `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`
   (copy `Config/Local.xcconfig.example`). It runs the whole preflight before it signs.
2. `Tools/release/export.sh` — writes the signed `.ipa` under `.build/release/export/`.
3. `Tools/release/upload.sh --upload --yes` — uploads to App Store Connect. Without
   `--upload` it only validates, which is the right first run.
4. Wait for the build to finish processing (10–60 minutes), then attach it under
   **Build** on the 1.0 page.
5. Attach the three in-app purchases to this version: on the 1.0 page, **In-App Purchases
   and Subscriptions → +** and add all three. A first version must submit its IAPs
   alongside the build, or they stay unapproved and every purchase fails in production.
6. **Add for Review → Submit to App Review**.

### Step 7 — After submission

- Export compliance is already answered by `ITSAppUsesNonExemptEncryption` in the
  binary (section 6), so no questions appear at upload.
- Set up **Sandbox Testers** (Users and Access → Sandbox) before review, so you can
  verify purchases on a real device yourself.
- If the app is rejected, `docs/store/audit-findings.md` lists the known review risks and
  what to answer.

---

## 8. Field checklist

| Field | Where in this doc | Status |
|---|---|---|
| Name, Subtitle | §1 | Ready |
| Categories, Age rating, Content rights | §1 | Ready |
| Promotional text, Description, Keywords | §2 | Ready |
| Support URL | §2 | **Placeholder — page must exist** |
| Marketing URL | §2 | Placeholder (optional field) |
| Privacy Policy URL + text | §2, §3.2 | Text ready; **page must exist** |
| App Privacy answers | §3.1 | Ready |
| 3 IAPs + group | §4 | Ready |
| App Review notes | §5 | Ready |
| Export compliance | §6 | Ready (in the binary) |
| Screenshots 6.9" / 6.5" | `screenshots.md` | Generated |
| Build upload | §7 step 6 | **Blocked on `DEVELOPMENT_TEAM`** |
| Paid Applications Agreement | §7 step 0 | **Blocked on the account owner** |
