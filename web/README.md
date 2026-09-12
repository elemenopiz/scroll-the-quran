# `web/` — the marketing and legal site

Plain static files. No framework, no build step, no JavaScript, no third-party requests.
Four pages plus a 404. The host is **Cloudflare Pages**; there is no second host
config to keep in sync.

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

## Clean URLs

The pages link to `/privacy`, `/support`, `/terms` — extensionless. Cloudflare Pages
serves those without the `.html` by default; `_redirects` additionally 301s the `.html`
spelling onto the clean URL so only one address is ever indexed or linked.

`_headers` carries the security headers: a CSP of `default-src 'none'` with `'self'` for
images, styles and fonts and nothing else (the site has no JavaScript, so there is no
`script-src` to allow), plus HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options`,
`Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`. Verify them
after the first deploy with `curl -sI https://scrollthequran.app/privacy`.

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

Proven on 2026-09-12 with wrangler 4.131.1:

```
/                200   /privacy.html    301 → /privacy
/privacy         200   /index.html      301 → /
/support         200   /support.html    301 → /support
/terms           200   /terms.html      301 → /terms
/nope            404 (404.html)
```

Wrangler resolves its config from the **current directory**, not from the directory
argument: `wrangler pages dev web` run at the repo root does not read `web/wrangler.toml`
(it warns about a missing `compatibility_date`), while `cd web && wrangler pages dev .`
does. That only affects the config file, not the served output — but see the deploy
section for what it means there.

## Deploying — Cloudflare Pages

Run these from the repo root. Only the first one needs the owner's browser.

```bash
npx wrangler login                                    # opens a browser; owner only, once
npx wrangler pages project create scroll-the-quran    # accept "main" as the production branch
npx wrangler pages deploy web --project-name scroll-the-quran
```

The `--project-name` flag is not optional from the repo root: wrangler looks for its
config in the current directory, so `web/wrangler.toml` (which carries `name =
"scroll-the-quran"`) is not read from there. The equivalent without the flag is

```bash
cd web && npx wrangler pages deploy .                 # reads web/wrangler.toml
```

Either way, each run prints a `https://<hash>.scroll-the-quran.pages.dev` preview URL;
deploys from the production branch also update `https://scroll-the-quran.pages.dev`.

Alternatively connect the GitHub repo in the dashboard (Workers & Pages → Create → Pages →
Connect to Git) with **root directory `web`**, **build command** empty, **output
directory `.`** — then every push to `main` redeploys.

### Custom domain and DNS

1. Cloudflare dashboard → the Pages project → **Custom domains** → **Set up a domain** →
   `scrollthequran.app`. Repeat for `www.scrollthequran.app`.
2. If `scrollthequran.app` already uses Cloudflare nameservers, Cloudflare writes the DNS
   records itself — accept the prompt and you are done.
3. If it does not, add the domain as a Cloudflare **zone** first (Add a site → Free plan),
   then change the nameservers at the registrar to the two Cloudflare gives you. Zone
   activation takes minutes to a few hours.
4. Keeping the registrar's DNS instead: add the records Cloudflare prints on the Custom
   domains screen — a `CNAME` for `www` → `scroll-the-quran.pages.dev`, and for the apex
   either a `CNAME` at the root (if the registrar supports CNAME flattening / ALIAS) or the
   `A` records Cloudflare lists. Cloudflare issues the TLS certificate once the record
   resolves.
5. Confirm with `curl -sI https://scrollthequran.app/privacy | head -1` before you paste the
   URL into App Store Connect. App Review opens `/support` and `/privacy`; a 404 there is a
   metadata rejection.

## Before submitting the app

- The App Store badge in the hero is a **placeholder** (`<span class="badge">`, marked
  `aria-disabled`). Swap it for Apple's official badge and link to the App Store product
  page once the app has one. Apple's badge artwork has its own usage rules — download it
  from the Apple Marketing Resources page rather than redrawing it.
- `support@scrollthequran.app` appears on three pages. Point it at a mailbox someone
  actually reads before review, or change it everywhere
  (`grep -rl support@scrollthequran.app web/`).
- Keep the "Last updated" dates on `/privacy` and `/terms` honest.
