# RevenueCat — dashboard, wiring, and what it costs in privacy

**Status: adapter written, SDK not added, app unchanged.** `AppShell` still injects
`StoreKitEntitlementStore` and the app still makes no network calls. What exists is
`Commerce/RevenueCatEntitlementStore.swift`, which conforms to the same
`EntitlementProviding` protocol the paywall already talks to, behind a
`RevenueCatClient` protocol that has no SDK behind it yet. Switching the app over is one
line at the composition root, after the two dependency lines in
[Adding the SDK](#adding-the-sdk-orchestrator) — which is the orchestrator's call, not this
task's, because it changes `Package.swift` and `project.yml`.

## Should you adopt it at all?

Honest answer: **you do not need RevenueCat to ship v1.** `StoreKitEntitlementStore` works,
it is tested, it reads the renewal state that grace-period handling needs, and it costs
nothing. RevenueCat earns its place when you want things StoreKit alone does not give you:

- **Revenue you can actually read** — MRR, trial conversion, churn and cohort retention,
  without building an analytics pipeline. App Store Connect's own reporting is worse than
  people expect and lags by a day or more.
- **Server-side entitlement truth**, which is what makes cross-platform or web access
  possible later, and what lets a support email be answered with facts.
- **Webhooks**: refunds, billing issues and cancellations as events you can act on.
  `BillingState.revoked` is unreachable from the client with RevenueCat (see below) —
  webhooks are where refunds actually show up.
- **Not having to write receipt validation** the day you add anything server-side.

What it costs: a third-party SDK that makes network calls, an App Privacy answer that
changes from "no data collected" to "purchase history, linked to you", and a dependency
in the purchase path — the most expensive place in the app to have a bug. Free under
$2.5k monthly tracked revenue; a percentage above that.

**Recommendation: ship v1 on StoreKit. Adopt RevenueCat when the second of these is
true** — you want the numbers, or you want a non-iOS surface. The adapter exists so that
decision is a one-line change instead of a rewrite.

## Dashboard setup

Every step here needs the owner's login. RevenueCat dashboard → app.revenuecat.com.

1. **Project** → *Create new project* → `Scroll the Quran`.
2. **Apps** → *+ New* → **App Store**:
   - App name: `Scroll the Quran`
   - **Bundle ID: `com.quranscroller.app`** — must match `project.yml`'s
     `PRODUCT_BUNDLE_IDENTIFIER` exactly.
   - **App Store Connect App-Specific Shared Secret** — App Store Connect → your app →
     App Information → *Manage* next to App-Specific Shared Secret. Required for receipt
     validation.
   - **In-App Purchase Key (.p8)** — App Store Connect → Users and Access → Integrations →
     In-App Purchase → *+*. Download once; upload the `.p8`, the Key ID and the Issuer ID.
     Without it RevenueCat cannot query subscription status server-side and things like
     refund detection silently do not work.
   - **App Store Server Notifications** — App Store Connect → your app → App Information →
     App Store Server Notifications → paste RevenueCat's Production and Sandbox URLs into
     **Version 2**. This is what makes renewals and refunds arrive in seconds rather than
     at the next app launch.
3. **Products** → *+ New*, one per row, identifiers copied **exactly** from
   `Packages/ScrollKit/Sources/Commerce/ProductID.swift`:

   | Product ID | Duration | Price (USA) | Trial |
   |---|---|---|---|
   | `com.scrollthequran.yearly` | 1 year | $29.99 | 7 days |
   | `com.scrollthequran.monthly` | 1 month | $4.99 | — |
   | `com.scrollthequran.yearly.gift` | 1 year | $19.99 | 3 days |

   A typo here is invisible until a customer taps Buy: the adapter throws
   `CommerceError.productUnavailable`, which the paywall renders as "not available right
   now". There is a test for exactly that branch.
4. **Entitlements** → *+ New* → identifier **`premium`** (lowercase; it is
   `RevenueCatConfiguration.premiumEntitlementID`). **Attach all three products to it.**
   The app asks "is `premium` active", never "which product did they buy" — so a fourth
   plan added here tomorrow unlocks the app with no release.
5. **Offerings** → *+ New* → identifier **`default`**, and mark it **current**. Packages:

   | Package | Product |
   |---|---|
   | `$rc_annual` (Annual) | `com.scrollthequran.yearly` |
   | `$rc_monthly` (Monthly) | `com.scrollthequran.monthly` |
   | `gift_annual` (custom) | `com.scrollthequran.yearly.gift` |

   The adapter reads the offering marked *current*, falling back to the one named
   `default` — so the two being the same offering is deliberate belt-and-braces.
6. **API keys** → Project settings → API keys. Copy the **public** Apple SDK key
   (`appl_…`). That is the only key that goes anywhere near the app. The **secret** key
   (`sk_…`) is for server calls and must never appear in the repo, the app bundle, or
   `web/`.

Do **not** turn on the RevenueCat **Paywalls** product. See
[Superwall: not for v1](#superwall-not-for-v1) — the same argument applies to RevenueCat's
own remote paywalls.

## Adding the SDK (orchestrator)

Two lines, both in files this task is not allowed to touch.

`Packages/ScrollKit/Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.0.0"),
],
…
.target(name: "Commerce", dependencies: [.product(name: "RevenueCat", package: "purchases-ios")]),
```

`project.yml` needs nothing: `Commerce` reaches the app through the `AppShell` product
that is already declared, and SwiftPM resolves the transitive dependency. If the widget
ever needs entitlements it would need its own `product: Commerce` line — it does not
today.

Then write the live client. It is the only new code, and it has no decisions in it —
every value type in `RevenueCatClient.swift` mirrors a RevenueCat type field for field:

```swift
import RevenueCat

@MainActor
final class LivePurchasesClient: RevenueCatClient {
    func configure(apiKey: String, appUserID: String?) {
        Purchases.logLevel = .warn
        Purchases.configure(with: .init(withAPIKey: apiKey).with(appUserID: appUserID))
    }
    func offerings() async throws -> RCOfferings { /* map Offerings */ }
    func purchase(_ package: RCPackage) async throws -> RCPurchaseResult {
        // RevenueCat throws ErrorCode.paymentPendingError for Ask to Buy and returns
        // userCancelled == true for a dismissal; fold both into RCPurchaseResult.
    }
    func restore() async throws -> RCCustomerInfo { /* Purchases.shared.restorePurchases() */ }
    func customerInfo() async throws -> RCCustomerInfo { /* Purchases.shared.customerInfo() */ }
    var customerInfoUpdates: AsyncStream<RCCustomerInfo> { /* Purchases.shared.customerInfoStream */ }
}
```

and finally, at the composition root:

```swift
// was: StoreKitEntitlementStore()
RevenueCatEntitlementStore(client: LivePurchasesClient(), apiKey: Secrets.revenueCatAPIKey)
```

No call site changes. The paywall reads `isPremium`, `products`, `introOfferEligible` and
`billingState` through `EntitlementProviding` and cannot tell the difference — there is a
test asserting exactly that (`"It is an EntitlementProviding, so the paywall needs no
change to use it"`).

### Keep the app user id anonymous

Pass `appUserID: nil`. RevenueCat then generates its own anonymous id. Sign in with Apple
is optional in this app and `credential.user` is an Apple-account identifier — handing it
to a third party turns an optional, on-device sign-in into a shared account identifier and
changes the privacy answers again. If an id is ever needed, use the same device-computed
`apple_sub_hash` the Supabase schema stores, never the raw value.

## `RC_API_KEY` wiring

The key is not a secret in the "leaks the bank" sense — it is a public SDK key, designed to
ship in a client — but it still does not belong in git, because rotating a committed key
means rewriting history. It rides the same path as `DEVELOPMENT_TEAM`:

1. **`Config/Local.xcconfig`** (gitignored; `Config/Local.xcconfig.example` is the
   template). Add:

   ```
   RC_API_KEY = appl_xxxxxxxxxxxxxxxxxxxxxxxx
   ```

   `Config/Base.xcconfig` already ends with `#include? "Local.xcconfig"`, so no other
   xcconfig changes. The `?` means a machine without the file still builds — which is why
   step 3 must tolerate the key being absent.
2. **`App/Info.plist`** gains one entry, so the value reaches the running app:

   ```xml
   <key>RCAPIKey</key>
   <string>$(RC_API_KEY)</string>
   ```

3. **Read it** at the composition root, and treat missing as "no RevenueCat", not as a
   crash:

   ```swift
   let key = Bundle.main.object(forInfoDictionaryKey: "RCAPIKey") as? String ?? ""
   ```

   `RevenueCatEntitlementStore(client:apiKey:)` already treats an empty key as "do not
   configure", so a CI build or a contributor without `Local.xcconfig` gets a store that
   loads nothing rather than an SDK that traps. Decide deliberately whether that falls
   back to `StoreKitEntitlementStore`; it probably should.
4. **CI**, if it ever signs a build, writes `Config/Local.xcconfig` from a secret. Never
   `echo` the key into a log.

Environment variable name for scripts and CI: **`RC_API_KEY`**. See
`docs/infra/README.md` and `.env.example`.

## Privacy consequences — read before shipping it

Adding RevenueCat makes three statements in `docs/store/metadata.md` false at once. They
are not "mostly" true afterwards; they are false, and App Review reads them.

1. **§3.1 App Privacy: "Do you or your third-party partners collect data from this app?"**
   flips from **No** to **Yes**. The supporting paragraphs say "the app makes zero network
   calls", "no analytics SDK, no crash reporter, no attribution SDK", and "there is no
   server we control". RevenueCat is a third-party partner that receives a purchase event
   with a user identifier. Declare:
   - **Purchases → Purchase History**, linked to the user, **App Functionality**.
   - **Identifiers → User ID**, linked to the user, **App Functionality** — RevenueCat's
     app user id, even an anonymous one, is a stable identifier for that install.
   - **Used for Tracking: No** (RevenueCat does not do cross-app tracking, and the app
     shows no ATT prompt). Keep it that way: do not enable RevenueCat's attribution or
     third-party integrations, which would change this answer *again*.
2. **`App/PrivacyInfo.xcprivacy`** — `NSPrivacyCollectedDataTypes` is empty today and must
   gain `NSPrivacyCollectedDataTypePurchaseHistory` and
   `NSPrivacyCollectedDataTypeUserID`, both `Linked: true`, `Tracking: false`, purpose
   `AppFunctionality`. RevenueCat ships **its own** `PrivacyInfo.xcprivacy` inside the SDK
   and Xcode merges it into the app's privacy report — but the SDK's manifest declares what
   *the SDK* does, not what *your app* does. Yours still has to declare it. Getting this
   wrong is an automated email from Apple after upload, not a human rejection.
3. **§3.2 privacy policy and `web/privacy.html`** — the text says "does not collect your
   data", "no servers", "makes no network requests of its own", "we never see or receive
   your payment details … the answer is kept on your device", and "there is nothing for us
   to show you, correct, export or delete". The purchases paragraph needs rewriting to
   name RevenueCat as a processor, say what it receives (a purchase event and an
   identifier) and what it does not (payment details — that part stays true, Apple never
   hands those to anyone), and the "no network requests" claim has to go. Two copies, one
   text: bump "Last updated" on both.

Also note **§1 Age rating → Unrestricted Web Access** and the Review Notes' "It is fully
offline … there is nothing to configure and no test server" — both need a sentence added.

### `BillingState.revoked` is unreachable with RevenueCat

`StoreKitEntitlementStore` can tell a refund from a lapse because
`Transaction.revocationDate` exists. RevenueCat's client-side `CustomerInfo` has no
equivalent: a refund simply removes the entitlement, which looks exactly like an expiry.
The mapping in `BillingState.init(entitlement:)` documents this and maps refunds to
`.expired`. If the app ever needs the difference, it comes from a RevenueCat **webhook**
(`CANCELLATION` with `reason: CUSTOMER_SUPPORT`), which means a server — i.e. the Supabase
project. Nothing in the current UI needs it.

## Sandbox testing

1. App Store Connect → Users and Access → **Sandbox** → add a tester.
2. On the device: Settings → App Store → **Sandbox Account** → sign in as that tester.
3. Buy on the paywall. RevenueCat dashboard → Customer History shows the transaction
   within seconds if the shared secret and the In-App Purchase key are right, and shows
   nothing at all if they are not — which is the fastest way to check step 2 of the
   dashboard setup.
4. Sandbox subscriptions renew on an accelerated clock (a year ≈ 1 hour), so grace period
   and billing retry are testable in an afternoon. The unit tests already cover the
   mapping; sandbox is for proving the SDK reports what the mapping expects.

## Superwall: not for v1

**Recommendation: do not adopt Superwall for v1.** Nor RevenueCat's own remote Paywalls
product; the argument is the same for both.

The paywall in this app is not a template with the numbers swapped in. It is a
pixel-matched clone of a specific screen, built from `DesignSystem` tokens, verified
against `Reference/paywall-trial.png` and `Reference/paywall-plans.png` by RMSE, and
covered by XCUITest layout specs. Superwall's proposition is that the paywall becomes a
remote template you edit in a dashboard and A/B test without a release. Taking it means:

- **Throwing away the thing that was built.** The clone becomes a Superwall template, and
  the snapshot tests that protect it have nothing left to protect — the screen can now
  change from a web dashboard without a build, which is precisely what those tests exist
  to prevent.
- **A second SDK in the purchase path**, on top of RevenueCat, with its own network calls,
  its own privacy manifest and its own failure mode: a paywall that cannot load.
- **Experiments you cannot yet run.** A/B testing a paywall needs traffic. At zero users
  the machinery costs a dependency and returns nothing; the first useful experiment is
  months after launch, and by then you will know which variant you actually want to test.
- **A third set of privacy answers** to keep consistent with §3.1, `PrivacyInfo.xcprivacy`
  and two copies of the policy — the three-document drift described above, again.

Keep **RevenueCat as the entitlement source of truth** and the native paywall as the UI.
Revisit Superwall when all three are true: the app has enough traffic for an experiment to
reach significance in under a month; there is a specific hypothesis about the paywall
worth testing; and someone is willing to own the tooling. Until then the native paywall is
an asset, not a constraint — and `EntitlementProviding` means the entitlement layer and
the paywall UI are already separable, so this decision stays reversible.
