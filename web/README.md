# `web/` — the marketing and legal site

Plain static files. No framework, no build step, no JavaScript, no third-party requests.
Four pages plus a 404:

| Route | File | Why it exists |
|---|---|---|
| `/` | `index.html` | Marketing URL in App Store Connect (optional field). |
| `/privacy` | `privacy.html` | **Required.** Privacy Policy URL. Verbatim `docs/store/metadata.md` §3.2. |
| `/support` | `support.html` | **Required.** Support URL — App Review opens it; a 404 here is a metadata rejection. |
| `/terms` | `terms.html` | Linked from the paywall (`PaywallLegalLinks`) and from the App Store description. |
| — | `404.html` | Served for anything else by both hosts. |

Supporting files: `assets/styles.css` (the only stylesheet), `assets/img/` (three
screenshots resized to 640 px from `docs/store/screenshots/6.9/`, the app icon),
`assets/fonts/` (the serif, see below), `robots.txt`, `sitemap.xml`.

## Design

Colours are the app's `DesignSystem` tokens in dark appearance, copied into CSS custom
properties at the top of `assets/styles.css` — `#0B0B0D` ground, `#1E1E23` cards,
`#38383B` dividers, `#FD8D32 → #E7533D` flame accent. If a token changes in
`Packages/ScrollKit/Sources/DesignSystem/Tokens.swift`, change it here too; nothing
automates that.

### The serif

`assets/fonts/scroll-serif-var.woff` is **Source Serif 4** (Adobe, SIL Open Font License
1.1 — licence copied to `assets/fonts/LICENSE-SourceSerif4.md`), subset to Latin and
converted to WOFF for the web (1.2 MB TTF → 218 KB). The OFL permits web use and
modification; clause 3 forbids a Modified Version from carrying the Reserved Font Name
"Source", so the subset's family name is **Scroll Serif**. The CSS falls back to
`Iowan Old Style`/`Georgia`/system serif when the file cannot load.

Regenerate it with the script recorded in `docs/infra/README.md` if the source font ever
changes.

## Clean URLs on both hosts

The pages link to `/privacy`, `/support`, `/terms` — extensionless — and both hosts serve
those without the `.html`:

- **Cloudflare Pages** does it by default. `_redirects` additionally 301s the `.html`
  spelling onto the clean URL so only one address exists.
- **Vercel** does it because `vercel.json` sets `"cleanUrls": true` (which also 308s
  `/privacy.html` → `/privacy`).

`_headers` (Cloudflare) and the `headers` array in `vercel.json` (Vercel) carry the same
security headers — CSP with `default-src 'none'`, HSTS, `X-Frame-Options: DENY`,
`X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`. **Change one, change
the other.**

`python3 -m http.server` has no clean-URL support; local testing there uses the `.html`
paths. `npx wrangler pages dev web` reproduces the real Cloudflare behaviour.

## Local preview

```bash
# Cloudflare's own runtime — clean URLs, _headers and _redirects all apply.
npx wrangler pages dev web --port 8788      # from the repo root, no login needed
curl -sI http://127.0.0.1:8788/privacy | head -1

# Or, with nothing installed (clean URLs will NOT work; use the .html paths):
python3 -m http.server 8080 --directory web
curl -sI http://127.0.0.1:8080/privacy.html | head -1
```

## Deploying — Cloudflare Pages (recommended)

```bash
npx wrangler login                                            # opens a browser; owner only
npx wrangler pages project create scroll-the-quran --production-branch main
npx wrangler pages deploy web --project-name scroll-the-quran
```

Or connect the GitHub repo in the Cloudflare dashboard (Workers & Pages → Create → Pages →
Connect to Git) with **root directory `web`**, **build command** empty, **output
directory `.`**.

Custom domain: Pages project → Custom domains → `scrollthequran.app` and
`www.scrollthequran.app`. If the domain's nameservers are already on Cloudflare the
records are created for you; otherwise Cloudflare shows the CNAME to add at the registrar.

## Deploying — Vercel

```bash
vercel login                     # owner only
vercel link                      # pick/create the project
vercel --prod                    # from the repo root
```

Set the project's **Root Directory** to `web` in Vercel → Settings → General, so
`vercel.json` and the pages are found. Then Settings → Domains → add
`scrollthequran.app`; Vercel prints the A record (`76.76.21.21`) or the CNAME
(`cname.vercel-dns.com`) to add at the registrar.

Which host to pick: see the "Cloudflare Pages vs Vercel" section of
`docs/infra/README.md`.

## Before submitting the app

- The App Store badge in the hero is a **placeholder** (`<span class="badge">`, marked
  `aria-disabled`). Swap it for Apple's official badge and link to the App Store product
  page once the app has one. Apple's badge artwork has its own usage rules — download it
  from the Apple Marketing Resources page rather than redrawing it.
- `support@scrollthequran.app` appears on three pages. Point it at a mailbox someone
  actually reads before review, or change it everywhere
  (`grep -rl support@scrollthequran.app web/`).
- Keep the "Last updated" dates on `/privacy` and `/terms` honest.
