# App Store screenshots

Generated, not hand-made. `Tools/release/screenshots.sh` drives the simulator through the
app's own `--screenshot` routes, slides each capture into the phone frame and writes both
App Store sizes. Re-run it whenever the UI changes; never retouch the PNGs by hand.

```bash
SCROLL_SIM=79A01D58-9B43-456D-A6B6-ABEA6D59C873 Tools/release/screenshots.sh
```

Output lands in `docs/store/screenshots/` and is committed — these are deliverables, not
build artefacts.

---

## What ships

| # | File | Route | Caption | Shows |
|---|---|---|---|---|
| 1 | `01-reader.png` | `reader` | One verse at a time | The reader on Al-Baqarah — muted Arabic above the English, one ayah filling the screen |
| 2 | `02-home.png` | `home` | Study any verse you choose | Home, opening on Verse Search with the surah/ayah pickers and "Study This Verse" |
| 3 | `03-discover.png` | `discover` | Discover by theme | A Discover card for Al-Ankabut 29:68-69 under the "Trust in God" theme, with Meaning, Did You Know and cross-references |
| 4 | `04-deepstudy.png` | `deepstudy` | Go deeper on every passage | Deep Study open on the same passage — the quote box then the Meaning section |
| 5 | `05-community.png` | `community` | Read together, give together | The Community tab: giving total, "Vote Who We Give To", and a charity card |

Five screenshots per size. App Store Connect allows up to 10; five is enough to tell the
story and every one of them earns its slot.

## Sizes

| Set | Pixels | Device class | Why |
|---|---|---|---|
| `6.9/` | **1290 x 2796** | iPhone 17 Pro Max / 16 Pro Max | The required iPhone set. Apple scales this down for smaller iPhones automatically. |
| `6.5/` | **1284 x 2778** | iPhone 14 Plus / 13 Pro Max | Optional. Generated because the slot still exists on the listing page and filling it costs nothing. |

Portrait only — the app is portrait-only (`UISupportedInterfaceOrientations` in
`App/Info.plist`), so there is no landscape set to produce.

No iPad set: the app ships iPhone-only. If iPad is ever added, a 13" set becomes required
and `SHOTS`/the canvas sizes in the script need a second pass.

## How the framing works

1. **Capture.** The raw simulator capture is **1206 x 2622** (iPhone 17 at @3x) — not an
   App Store size, which is why framing is not optional.
2. **Fit into the frame.** `Artwork/Frames/phone-frame-1179x2556.png` is a transparent
   PNG with a screen window at x30 y30, 1119 x 2496, corner radius 160. The capture is
   0.460:1 and the window is 0.448:1, so the capture is scaled to **fill** and
   centre-cropped — never stretched — then its corners are rounded to the window's radius
   and the frame is composited *on top*, so the bezel and the Dynamic Island overlap it
   correctly.
3. **Compose.** The framed phone is laid on a `#241D16 → #0B0B0D` vertical gradient at
   80% of the canvas width, 13.5% down from the top, with the caption set in
   Poppins SemiBold above it.
4. **Flatten.** Alpha is removed and the result is written as sRGB with metadata
   stripped. App Store Connect rejects PNGs with an alpha channel.

## Determinism

Captures are reproducible, which is the only reason regenerating them is safe:

- `SCROLL_FIXED_DATE=2026-09-14` is passed into the app, so the Discover feed, the
  "today" card and the streak week all resolve to the same day every run. That is why
  runs keep landing on Al-Ankabut 29:68-69.
- The `--screenshot <route>` entry point boots straight into one screen with fixture
  data and a fixture entitlement store, so premium content is unlocked and no purchase,
  onboarding or network state can vary.
- Dark appearance is forced per shot via `simctl ui … appearance dark`.
- The simulator is pinned to **ScrollSim-3d** by UDID, never `booted` — other agents run
  their own simulators in parallel and `booted` is ambiguous the moment two are up.

## The blank-screen trap

A capture taken before the screen reaches first paint is a **black rectangle** that passes
every other check in the script: correct dimensions, no alpha channel, and it composites
into the frame looking like a switched-off phone. The first run of this script produced
exactly that for `discover` and `deepstudy` — both read a study shard at launch and need
longer than the reader to draw — and the sets "passed".

So the script now proves each capture has content before accepting it:

- Crop off the top 300px (the status bar always draws, even on a blank screen) and measure
  the standard deviation of what is left.
- A screen that has not painted scores **exactly 0.00**. A drawn screen in this app's dark
  palette scores **8–13**. The threshold is 1.0, sitting in a very wide gap.
- On a blank reading the script waits and re-captures, up to `SCROLL_CAPTURE_TRIES`
  (default 5) attempts of `SCROLL_CAPTURE_SETTLE` seconds (default 4), then fails with the
  command to reproduce it by hand.
- The same check guards `--frames-only`, which would otherwise happily re-frame a stale
  blank capture.

If a route starts failing this check, the route is broken or much slower than it was —
raise `SCROLL_CAPTURE_SETTLE` only after confirming the screen actually renders.

## Flags

| Flag | Use |
|---|---|
| *(none)* | Build, install, capture, frame, verify, shut the simulator down |
| `--no-build` | Reuse the app already in `.build/DerivedData` — much faster when only captions or framing changed |
| `--frames-only` | Re-frame the existing captures in `.build/screenshots`; no simulator at all |
| `--keep-booted` | Leave the simulator running (useful while iterating) |

## Uploading

App Store Connect → the app → **1.0 Prepare for Submission** → Previews and Screenshots.
Choose **iPhone 6.9" Display**, drag in all five files from `docs/store/screenshots/6.9/`;
they sort by filename, which is the intended display order. Repeat for **6.5"** if you
want that slot filled.

Do not add text overlays in App Store Connect — the captions are already burned in.

## Known limitations

These are honest gaps in the current set, not blockers. Fix before a marketing push.

1. **The streak reads zero.** The fixture user state has no reading history, so Home shows
   "0 DAYS OPENED" and "0% QURAN READ". That is why the Home slot uses the unscrolled
   `home` route (Verse Search) rather than `home#scrolled` — the scrolled route puts an
   empty streak front and centre. A lived-in fixture (a ~12-day streak, a few percent
   read, a plan in progress) would make a materially better screenshot and would let
   "Keep a daily rhythm" back into the set. The fixture lives outside this task's
   ownership; logged in `audit-findings.md`.
2. **Community shows "$0" given.** Same cause. Truthful for a pre-launch build, and it
   must stay truthful — do **not** fake a number here. Once real giving exists, re-capture.
3. **The reader shot has two soft spots**, both visible in the committed
   `01-reader.png` and both judged acceptable rather than blocking:
   - The "Tap or slide to jump to any verse" coaching toast is showing. It is a
     first-launch hint tied to `ReaderHintStore`, so whether it appears depends on
     simulator state. It reads as a genuine affordance rather than an error, so it stays;
     to drop it, dismiss the hint once on ScrollSim-3d and re-run with `--no-build`.
   - The `reader` route opens on the surah's **page 0** — the Bismillah header — rather
     than a numbered ayah. It shows the muted-Arabic-over-English treatment exactly as
     the caption promises, but it is the sparsest page in the set. A route that opened on,
     say, 2:255 would be denser; adding one is an `AppShell` change, outside this task.
4. **No paywall screenshot in the marketing set.** Deliberate — leading with a price does
   not sell a reading app. The paywall captures App Review needs for the IAP review
   screenshots are separate; see `metadata.md` §4.
