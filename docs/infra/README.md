# Infrastructure — what exists, what is live, and the order to do it in

Three services sit around the app: **Cloudflare Pages** hosts the marketing and legal site,
**Supabase** is a sync backend that is scaffolded but switched off, and **RevenueCat** is a
purchase adapter that is written but not wired in.

**Nothing in the shipped app changed.** The app still makes no network calls, still sells
through StoreKit 2, still declares no collected data. Everything here is either outside the
app (the website) or behind a seam the app does not yet use.

| | Where | State | Needs the owner's login? |
|---|---|---|---|
| Marketing + legal site | `web/` | **Ready to deploy.** Four pages, proven locally. | Yes — `wrangler login`, once |
| Supabase backend | `supabase/` | **Scaffolded, unused.** Schema written and validated; no project exists. | Yes — `supabase login`, and creating the project |
| RevenueCat | `Commerce/RevenueCat*.swift` | **Adapter written, SDK not added.** App still uses StoreKit. | Yes — dashboard, keys |
| App Store metadata | `docs/store/metadata.md` | Written. The Support and Privacy URLs point at the site below. | — |

Read this page once, then the per-service README when you get to it:
[`web/README.md`](../../web/README.md) · [`supabase/README.md`](../../supabase/README.md) ·
[`docs/infra/revenuecat.md`](revenuecat.md).

---

## Do these in order

The order matters: the site is a **submission blocker** (App Review opens `/support` and
`/privacy`, and a 404 there is a metadata rejection), while Supabase and RevenueCat are
both optional for v1 and both *change the privacy answers* if adopted.

### 1. Cloudflare Pages — the website (do this one)

```bash
npx wrangler login                                            # browser; owner only, once
npx wrangler pages project create scroll-the-quran            # accept "main" as production branch
npx wrangler pages deploy web --project-name scroll-the-quran
```

Then, in the Cloudflare dashboard: the Pages project → **Custom domains** →
`scrollthequran.app` and `www.scrollthequran.app`. If the domain's nameservers are already
on Cloudflare the DNS is written for you; if not, add the zone first or copy the records
Cloudflare prints to your registrar. `web/README.md` has the fork spelled out.

Done when all four of these return `200`:

```bash
for p in / /privacy /support /terms; do curl -so /dev/null -w "%{http_code} $p\n" "https://scrollthequran.app$p"; done
```

Before you paste the URLs into App Store Connect, fix the two placeholders `web/README.md`
lists: the **App Store badge** in the hero (currently a disabled `<span>`) and
**`support@scrollthequran.app`**, which must be a mailbox someone reads during review.

### 2. Supabase — only if you want sync

Not needed to ship. Skip it and nothing breaks; the app keeps everything in the App Group
container, which is what the privacy policy currently describes.

```bash
supabase login                              # browser; owner only, once
# Dashboard -> New project ("scroll-the-quran"); choose a region; save the DB password
supabase link --project-ref <ref>
supabase db push                            # applies supabase/migrations/0001_init.sql
```

Then Project Settings → API → copy the URL and `anon` key into `supabase/.env`.

**The day the app makes its first request to Supabase, three documents must change in the
same release** — the privacy manifest, the App Privacy answers, and both copies of the
privacy policy. `supabase/README.md` § *Before this goes live* is the checklist, and it is
not optional: shipping the sync without it is a manifest mismatch and an App Review
rejection.

### 3. RevenueCat — only if you want the numbers

Also not needed to ship, and `docs/infra/revenuecat.md` argues for **launching without
it**: `StoreKitEntitlementStore` already works, is tested, and reads the renewal state
grace-period handling needs. RevenueCat earns its place when you want revenue analytics you
can actually read, or a non-iOS surface later.

If you do adopt it: dashboard → project → app with bundle id `com.scrollthequran.app` →
shared secret + In-App Purchase key → three products → the `premium` entitlement → the
`default` offering → copy the public `appl_…` key. Then the orchestrator adds the SPM
dependency and writes the live client; the adapter and its 33 tests are already here. The
full click-path, the two dependency lines and the privacy consequences are in
[`revenuecat.md`](revenuecat.md).

**Superwall: not for v1.** The paywall is a pixel-matched native clone under snapshot and
XCUITest protection; replacing it with remote templates throws that away to buy A/B tests
there is not yet traffic to run. Reasoning in `revenuecat.md`.

---

## Environment variables

| Name | Used by | Where it actually lives |
|---|---|---|
| `RC_API_KEY` | the app, via RevenueCat | `Config/Local.xcconfig` → `App/Info.plist` as `RCAPIKey`. **Not** read from `.env`. |
| `SUPABASE_URL` | the app, if sync ships | `supabase/.env` for tooling; the app would read it from `Info.plist` the same way. |
| `SUPABASE_ANON_KEY` | the app, if sync ships | as above. An RLS-scoped public JWT — safe in a client, still not in git. |
| `SUPABASE_SERVICE_ROLE_KEY` | server only | the Supabase dashboard. Bypasses every RLS policy; never in the app, never in `web/`. |
| `REVENUECAT_SECRET_KEY` | server only | the RevenueCat dashboard. Never in the app. |
| `CLOUDFLARE_API_TOKEN` | unattended CI only | not needed — `wrangler login` uses a browser session. |

Templates, both tracked, neither containing a value:

- [`.env.example`](../../.env.example) — every name in one place, with a note on which are
  server-only.
- [`supabase/.env.example`](../../supabase/.env.example) — the Supabase subset, plus the
  Apple provider secret for local dev.
- `Config/Local.xcconfig.example` — already existed for `DEVELOPMENT_TEAM`; `RC_API_KEY`
  goes in the same file. (Adding it there is the orchestrator's edit — `Config/` is outside
  this task's scope.)

Ignored in [`.gitignore`](../../.gitignore): `.env`, `.env.local`, `supabase/.env`,
`Config/Local.xcconfig`, `.wrangler/`, `web/.wrangler/`.

## Which of these can be done without the owner

None of the three service setups. Every one begins with a login that opens a browser —
`wrangler login`, `supabase login`, and the RevenueCat dashboard — and none of them can be
delegated to a key, because the key is what the login issues.

What *has* been done without them: the site is written and its routing proven against
Cloudflare's own runtime locally; the Supabase schema is written and applied for real
against a local PostgreSQL 17, RLS and all, with a behavioural pass over every policy and
constraint; the RevenueCat adapter is written, compiles with no SDK present, and is covered
by 33 tests. Each service is one login away from live, and nothing about the app changes
when it gets there.
