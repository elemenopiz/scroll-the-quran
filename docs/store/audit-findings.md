# Audit findings — Phase 4c

Three audits were run over `Packages/ScrollKit/Sources`, `App/`, `Widget/` and `Config/`
before submission: **security & privacy**, **accessibility**, and **in-app purchase /
StoreKit**.

Phase 4c owns `App/PrivacyInfo.xcprivacy`, `Config/**`, `docs/store/**`,
`Tools/release/**`, `App/Info.plist`, and `project.yml` for archive/export/privacy
settings only. Almost every finding lands in `Packages/ScrollKit/Sources`, which this
task does not own — those are listed here with file, line and severity, and nothing was
edited outside the owned paths.

**Headline:** nothing found is an automatic App Store rejection. Two findings are real
review risks worth fixing before submitting (IAP-1 and IAP-2). One accessibility finding
is a genuine WCAG failure across most of the app (A11Y-1).

---

## Scoreboard

| Audit | Critical | High | Medium | Low | Fixed here | Listed |
|---|---|---|---|---|---|---|
| Security & privacy | 0 | 2 | 1 | 1 | 0 | 4 |
| Accessibility | 1 | 3 | 3 | 2 | 0 | 9 |
| IAP / StoreKit | 0 | 3 | 1 | 2 | 1 | 5 |
| Store-readiness (found while writing metadata) | 0 | 0 | 1 | 0 | 2 | 1 |

Verdicts the audits returned: security **READY (with gaps)**, accessibility **GAPS**,
IAP **NEEDS WORK**.

---

## Fixed in this task (inside Phase 4c ownership)

### FIXED-1 — IAP descriptions were longer than App Store Connect allows
**File:** `Config/ScrollTheQuran.storekit`
**Severity:** Medium (would have blocked entering the product metadata, not the build)

App Store Connect caps an in-app purchase **Description** at 45 characters. Two of the
three products were over it:

| Product | Was | Length | Now | Length |
|---|---|---|---|---|
| `com.scrollthequran.yearly` / `.monthly` | "Full access to Deep Study, reading plans and every translation." | 63 | "Deep Study, every plan, every translation." | 42 |
| `com.scrollthequran.yearly.gift` | "One-time welcome offer: Premium for a year at 33% off." | 54 | "A year of Premium at 33% off. One time." | 39 |

The local `.storekit` file has no length limit of its own, so this would not have
surfaced until someone was typing into App Store Connect and got truncated. The test
configuration and `docs/store/metadata.md` §4 now carry the same strings that will
actually be entered. No test asserts on these strings (checked); `Tools/verify.sh`
passes after the change.

### FIXED-2 — `export.sh --validate` could not validate anything
**File:** `Tools/release/export.sh`
**Severity:** Medium (a DoD check that silently could not work)

Two separate bugs, each hiding the other:

1. The schema check captured `xcodebuild -help` with `2>/dev/null`, but that command
   writes its entire output to **stderr**. `$HELP` was always empty, so every key lookup
   failed — the check could not have passed for any key, ever.
2. `--validate` called `require_team` first and exited 3 without a Team ID, so nothing
   ever reached bug 1. The dry run's whole purpose is to prove the options plist before a
   10-minute archive exists, which matters most on a checkout with no signing configured
   — precisely the case it refused to run in.

Now: `--validate` falls back to the placeholder team (warning twice that `teamID` is not
real) and checks all 8 keys plus the `app-store-connect` method against the
"Available keys for -exportOptionsPlist:" section of this Xcode's help. A real export
still requires a team and still exits 3 without one. Committed separately.

### FIXED-3 — screenshot captures could ship as blank screens
**File:** `Tools/release/screenshots.sh`
**Severity:** Medium

See `screenshots.md` § "The blank-screen trap". The first generated sets contained two
black rectangles that passed every existing check. Captures now have to prove they drew.

### Confirmed correct, no change needed

- **`App/PrivacyInfo.xcprivacy` is accurate.** The security audit independently verified
  that the four undeclared required-reason API categories (file timestamps, disk space,
  system boot time, active keyboards) genuinely have no call sites, and that the one
  declared category (UserDefaults, reason `CA92.1`) matches the code. The App Privacy
  answers in `metadata.md` §3.1 are consistent with it.
- **`ITSAppUsesNonExemptEncryption = false`** in `App/Info.plist` is correct — no
  CryptoKit/CommonCrypto usage anywhere, and no network calls at all.
- **No third-party SPM dependencies** (`Package.swift` has zero `.package()` entries),
  which removes the "bundled SDK is missing its own privacy manifest" rejection class
  entirely.
- **No hardcoded credentials.** `ABCDE12345` in `Config/Local.xcconfig.example` and in
  the `.storekit` file is a documented placeholder, not a leaked Team ID.
- **No logging at all** — zero `print`/`NSLog`/`Logger` call sites, so there is no
  sensitive-data-in-logs surface.

---

## Listed — outside Phase 4c ownership

Ordered by what to fix first.

### IAP-1 — Purchase and restore failures are invisible to the user
**Severity: HIGH.** Real App Review risk.
**File:** `Packages/ScrollKit/Sources/FeaturePaywall/PaywallFlow.swift:22-26, 80-116, 171-213`

`PaywallModel` computes `errorMessage`, `pendingMessage` (Ask to Buy) and `isPurchasing`
correctly — and **no view ever reads them**. `PaywallTrialView`, `PlansSheet` and
`GiftOfferView` contain no alert, no bound text and no spinner tied to that state.

A declined card, a parental-controls block, an ineligible offer, or a restore that finds
nothing all produce **zero visible feedback** — the button simply stops responding.
Sandbox reviewers hit declined and ineligible purchases routinely, and "the purchase
button does nothing" is a classic rejection.

`PaywallModelTests` tests every model transition but never asserts the state reaches a
view, which is exactly how this shipped.

**Fix:** bind `model.errorMessage` to an alert, surface `pendingMessage` inline under the
CTA, and disable/spin the button while `isPurchasing`. Add one UI-level test so it cannot
regress silently.

### IAP-2 — The gift offer screen has no Terms/Privacy links and no Restore
**Severity: HIGH.** Guideline 3.1.2(a) risk.
**File:** `Packages/ScrollKit/Sources/FeaturePaywall/GiftOfferView.swift` (whole file)

`GiftOfferView` is an independent purchase surface for a real auto-renewing subscription
with a 3-day trial (`com.scrollthequran.yearly.gift`). Its only disclosure is the
footnote "3 days free, then $19.99/year • Cancel anytime" (lines 162-166, 260-265). There
are no Terms of Use / Privacy Policy links and no Restore Purchases affordance anywhere
on it. A reviewer who reaches the gift offer without going back through the main paywall
sees a "Start FREE trial" button with none of the required legal affordances.

**Fix:** reuse `PaywallTrialView.legalRow` and thread `PaywallLegalLinks` + `onRestore`
through `PaywallFlow.gift` the way `trial` already does.

### A11Y-1 — The app-wide UI text token does not scale with Dynamic Type
**Severity: CRITICAL (WCAG 1.4.4 AA).**
**File:** `Packages/ScrollKit/Sources/DesignSystem/Typography.swift:63-70`

`Font.body(_:weight:)` and `Font.capsLabel(_:)` are `.system(size:)` with no
`relativeTo:`, so they are pinned at their literal point size. `Font.body` alone is used
**119 times across 39 files** — settings rows, library rows, buttons, toolbar labels,
notes, Deep Study prose, community copy. There is no `@ScaledMetric` anywhere in the
codebase either.

A user on a larger Dynamic Type setting sees **no change** to nearly the entire app. The
verse/serif and paywall fonts do scale, so this is specifically the general UI text.

**Fix:** one design-system-level change to the two tokens. It will need a follow-up
layout pass, because fixed row heights (`RowLink`, `ExploreRow`, the `NotesSheet` editor's
fixed `height`) have never had to accommodate growing text.

### A11Y-2 — `Color.textTertiary` fails contrast for real body text
**Severity: HIGH (WCAG 1.4.3 AA).**
**File:** `Packages/ScrollKit/Sources/DesignSystem/Tokens.swift:104`

`#8E8E93` light / `#7D7D7E` dark measures ≈3.27:1 on light and ≈4.0:1 against
`cardBackground` on dark — under the 4.5:1 needed for normal-size text. That is fine for
the decorative, `accessibilityHidden` Arabic layer it was designed for, but the same
token is reused for load-bearing text at 12-16pt: translation licence/copyright
(`SurahPicker.swift:92`), the "Delete my data" footer (`SettingsView.swift:212`),
"Day n of N" (`TodaysReadingCard.swift:33`), the notes autosave label
(`NotesSheet.swift:93`), and ~12 more sites.

**Fix:** split the token — keep the current muted value for the Arabic layer (rename it,
e.g. `textQuaternary`) and raise `textTertiary` to a contrast-safe value for real text.

### A11Y-3 — VoiceOver focus does not follow the paywall → gift / plans transitions
**Severity: HIGH.**
**Files:** `Packages/ScrollKit/Sources/FeaturePaywall/PaywallFlow.swift:193,205`;
`PlansSheet.swift`; `GiftOfferView.swift`

`PlansSheet` and `GiftOfferView` are drawn as plain views inside a `ZStack`/state swap
rather than presented with `.sheet`/`.fullScreenCover` — deliberate, so the snapshot
routes render synchronously (comment at `PlansSheet.swift:6-9`). The cost is that SwiftUI
posts no screen-changed notification, so a VoiceOver user's cursor stays on the previous
screen and they may never discover the gift offer exists.

**Fix:** post `UIAccessibility.post(notification: .screenChanged, argument: nil)` on the
phase change, or use `@AccessibilityFocusState` on the new screen's title.

### IAP-3 — No subscription status tracking (grace period / billing retry)
**Severity: HIGH (churn, not rejection).**
**File:** `Packages/ScrollKit/Sources/Commerce/StoreKitEntitlementStore.swift:111-134`

Entitlement comes only from `Transaction.currentEntitlements`.
`Product.SubscriptionInfo.Status` and `RenewalInfo` are read nowhere in the repo. During
Apple's billing grace period access is correctly preserved, but the user is never told
their payment failed — so when the grace period lapses, `isPremium` silently flips to
false and it reads as "the app just stopped working" rather than "update your card".

**Fix:** read `product.subscription?.status` in `refreshEntitlements()` and surface a
banner for `.inGracePeriod` / `.inBillingRetryPeriod`.

### SEC-1 — Sign in with Apple identity stored in plaintext UserDefaults
**Severity: HIGH.**
**File:** `Packages/ScrollKit/Sources/FeatureOnboarding/OnboardingStores.swift:61-91`
(`UserDefaultsAccountSink`); wired in at `OnboardingFlow.swift:19`

On a real cold launch the default `OnboardingFlow` parameter is
`UserDefaultsAccountSink()`, which writes the Apple stable user identifier, email and
formatted full name straight to `UserDefaults.standard` under `accountId`,
`accountEmail`, `accountName`. No Keychain exists anywhere in the codebase
(`import Security` appears in no file).

This is not an App Store rejection — Apple does not mandate Keychain here — and the
privacy manifest's `NSPrivacyCollectedDataTypes: []` claim remains accurate, because
nothing is *transmitted*. It is still more PII sitting in the clear (and in unencrypted
backups) than this app needs.

### SEC-2 — Onboarding's sign-in never reaches `UserStore`, so Settings always says "Not signed in"
**Severity: HIGH (functional bug).**
**File:** `Packages/ScrollKit/Sources/FeatureOnboarding/OnboardingModel.swift:99-104`

There are two unrelated account protocols: `FeatureOnboarding.OnboardingAccountSink`
(backed by UserDefaults) and `UserState.AccountSink` (backed by `UserStore`, written to
the App Group `prefs.json`, and read by `SettingsView.swift:121-128`). Onboarding only
ever calls the first. Nothing anywhere calls `UserStore.signIn(accountID:email:)`
(`UserStore+Actions.swift:242-270`).

A user who completes Sign in with Apple will still see "Not signed in" in Settings
forever. A reviewer testing Sign in with Apple may well notice.

**Fix:** SEC-1 and SEC-2 are one change — inject `UserStore` as the onboarding account
sink and delete `UserDefaultsAccountSink`. That closes the plaintext storage gap and the
functional bug together.

### A11Y-4 — Reduce Motion is ignored in the reader and Community
**Severity: HIGH.**
**Files:** `Packages/ScrollKit/Sources/FeatureReader/VerseRail.swift:87,95`;
`FeatureCommunity/CommunityView.swift:71`

Explicit `.easeOut` animations with no `accessibilityReduceMotion` check — while
`OnboardingFlow.swift:39/50`, `PillButtons.swift:78-86` and `GiftOfferView.swift:15/44-51`
all do check it. `VerseRail` fires on every ayah crossed, i.e. continuously while
reading, on the app's most-used screen.

**Fix:** match the existing pattern — `.animation(isDragging || reduceMotion ? nil : …)`.

### A11Y-5 — Touch targets under 44×44pt
**Severity: MEDIUM.**

- `DesignSystem/Components/ComponentMetrics.swift:29,31,33` — `capsuleGroupHeight = 36`,
  used by the reader toolbar's dice/heart (`ReaderToolbar.swift:25-42`). The file's own
  comment says its controls are "grown to a 44 pt hit target" but explicitly excludes
  this group.
- `FeatureDiscover/DeepStudySections.swift:57` — copy-section button, 28×28.
- `DesignSystem/Components/ToastHint.swift:42` — toast dismiss ×, 32×32.
- `FeatureDiscover/DeepStudySections.swift:200` — `ExploreRow`, height 41.

**Fix:** `.frame(minWidth: 44, minHeight: 44).contentShape(.rect)` around the existing
visual size, as `ReaderToolbar.swift:67/82/105` already does for its own controls.

### IAP-4 — Injected `PaywallLegalLinks` is stored but never passed to the view
**Severity: MEDIUM (currently harmless).**
**File:** `Packages/ScrollKit/Sources/FeaturePaywall/PaywallFlow.swift:137, 148, 171-202`

`PaywallFlow.init` takes `links:` and stores it, but `trial` builds `PaywallTrialView`
without passing it, so the view falls back to its own `.default` static
(`PaywallTrialView.swift:17`). Both defaults resolve to the same URLs today, so nothing
is broken — but any future change to the injected links would silently do nothing.

**Fix:** `PaywallTrialView(..., links: links)` at the call site.

### IAP-5 — Trial paywall CTA has no adjacent auto-renewal copy
**Severity: LOW.**
**File:** `Packages/ScrollKit/Sources/FeaturePaywall/PaywallTrialView.swift:99-144`

`PaywallCopy.cancelAnytime` is rendered in `PlansSheet` but not on the trial screen,
whose Redeem button can purchase directly. Mitigated by the working Terms link and the
visible price/period in the same footer.

### SEC-3 / SEC-4 — Keychain and sign-out completeness
**Severity: MEDIUM / LOW.** Both follow from SEC-1.

- No Keychain wrapper exists, so fixing SEC-1 means introducing one
  (`kSecClassGenericPassword`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- `UserDefaultsAccountSink.clearEmail()` (`OnboardingStores.swift:88-90`) clears only the
  email key, never `accountId`/`accountName`. Latent today (nothing calls sign-out
  against this sink), but it would leak straight through a SEC-2 fix applied on its own.
  `UserState.AccountSink.signOut()` already does this correctly.

### IAP-6 — Unverified transactions are dropped silently
**Severity: LOW.**
**File:** `Packages/ScrollKit/Sources/Commerce/StoreKitEntitlementStore.swift:136-141`

`.unverified` results are neither logged nor finished, so they redeliver on every launch
with no visibility. Correct in refusing entitlement; no revenue or security risk.

### A11Y-6 — Arabic/English size ratio at accessibility text sizes
**Severity: MEDIUM (design QA, not a code bug).**
**File:** `Packages/ScrollKit/Sources/DesignSystem/Typography.swift:50-59`

`Font.arabicAccent` is deliberately non-scaling and documented as such — letting Dynamic
Type grow the decorative layer would push the English off the page. Correct. But once
A11Y-1 is fixed and the English scales to AX5 while the Arabic stays fixed at ~58% of the
*base* size, the ratio will distort. Needs a manual AX5 pass on reader, Discover and Deep
Study rather than a code change.

### STORE-1 — Screenshot fixtures show an empty app
**Severity: MEDIUM (marketing, not review).**

The fixture user state has no reading history, so Home shows "0 DAYS OPENED" / "0% QURAN
READ" and Community shows "$0" given. This is why the marketing set uses the unscrolled
`home` route instead of `home#scrolled` (see `screenshots.md` § Known limitations). A
lived-in fixture — a ~12-day streak, a few percent read, a plan in progress — would make
a materially better screenshot set and let a "keep a daily rhythm" shot back in. The
fixture lives in `AppShell`/`UserState`, outside this task.

---

## What the audits confirmed is fine

Worth recording so it is not re-litigated:

- **The muted-Arabic accessibility pattern is implemented correctly everywhere.**
  `ArabicAccentText` (`DesignSystem/Components/VerseText.swift`) is always
  `accessibilityHidden(true)`, and every call site traced — `VerseText`, `KeyTermsList`,
  the widget's `VerseWidgetView` — pairs it with a sibling carrying the real English
  label. **No orphaned Arabic-only surface was found.**
- **Restore Purchases exists in two places**, both reaching `AppStore.sync()`: the paywall
  footer (`PaywallTrialView.swift:140-169`) and Settings
  (`SettingsView.swift:137-157`, id `settings.restorePurchases`).
- **StoreKit 2 transaction handling is correct**: `Transaction.updates` starts in
  `StoreKitEntitlementStore.init()` and is never cancelled early, every verified
  transaction is `finish()`ed, and `VerificationResult` is unwrapped at every read site.
  No StoreKit 1 anywhere.
- **VoiceOver label coverage is >95%** across ~40 interactive elements spot-checked; no
  missing-label instances were found, and all 6 gesture-based interactions have an
  accessibility equivalent.
- **No server-side receipt validation** is an intentional architectural constraint
  (CLAUDE.md rule 9), not an oversight.
- **The Community tab moves no money.** It lists organisations, takes a non-binding vote
  and links out in Safari — no donation flow, no user-generated content. Stated in the
  App Review notes.
