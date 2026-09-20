# `supabase/` — the sync backend, scaffolded and switched off

Nothing in the shipped app talks to Supabase. `CLAUDE.md` rule 9 ("no network calls in the
app") still holds, `App/PrivacyInfo.xcprivacy` still declares no collected data, and the
App Privacy answer in `docs/store/metadata.md` §3.1 is still **"No"**. This directory is
the schema and the runbook for the day the owner decides to sync — and the checklist of
what else has to change in the same release when that day comes (see
[Before this goes live](#before-this-goes-live), which is not optional).

| File | What it is |
|---|---|
| `config.toml` | `supabase init` output, edited: project id `scroll-the-quran`, `site_url` and the redirect allow-list, and an `[auth.external.apple]` block with the bundle id filled in. |
| `migrations/0001_init.sql` | The whole schema: five user tables, one catalogue table, RLS on all six, `handle_new_user`, `touch_updated_at`, `charity_tally_rows()` and the `charity_tallies` view. |
| `seed.sql` | The three charities from `Content/charities.json`. Idempotent (`on conflict do update`). |
| `.env.example` | The variable names. Copy to `supabase/.env`, which is gitignored. |

## The schema

```
auth.users                          Supabase Auth — Sign in with Apple
  └─ public.profiles                id = auth.users.id, created by the on_auth_user_created trigger
       ├─ library                   saved verse "2:255" / passage "94:5-6" keys
       ├─ notes                     one private note per verse
       ├─ charity_votes             at most one *active* vote per profile
       └─ reading_progress          exactly one row per profile

public.charities                    mirror of Content/charities.json, read-only to users
public.charity_tallies (view)       what the Community tab reads: counts, never voters
```

Decisions worth knowing before you extend it:

- **The Apple user identifier is never stored.** `profiles.apple_sub_hash` holds a SHA-256
  of it, computed on the device, with a check constraint that rejects anything that is not
  64 lowercase hex characters — so a raw Apple `sub` written there by mistake fails loudly
  instead of sitting in the table. It is nullable, because signing in is optional and the
  app has to work for a user who never does.
- **Verse keys are validated in the database.** `library.key` and `notes.verse_key` must
  match `^[0-9]{1,3}:[0-9]{1,3}(-[0-9]{1,3})?$`, the app's own key grammar
  (`CLAUDE.md`: verse `"2:255"`, passage `"94:5-6"`). A malformed key cannot be synced up
  and then fail to resolve on another device.
- **One active vote per profile, without losing the history.** Superseding a vote sets
  `withdrawn_at` on the old row; the partial unique index
  `charity_votes_one_active_idx ... where withdrawn_at is null` is what makes "one active
  vote" true rather than merely intended.
- **`reading_progress.read_bitset` is exactly 780 bytes** — `ceil(6236 / 8)`, one bit per
  global verse index (`surah.startIndex + ayah - 1`). A check constraint enforces the size,
  so a bitset built against a wrong verse count is rejected at the door.
- **`charity_tallies` cannot leak a vote.** A plain view fails in both directions: with
  invoker rights RLS reduces every tally to the caller's own single vote; with definer
  rights the view becomes a way to read past RLS one filter at a time. So the aggregation
  happens inside `charity_tally_rows()`, a `security definer` function whose *return type*
  is the privacy boundary — it emits `(charity_id, votes)`, takes no arguments, and there
  is therefore no question you can ask it that identifies a voter. The view joins those
  totals onto the catalogue with invoker rights.
- **Both `security definer` functions pin `search_path = ''`** and schema-qualify every
  name. Without that, a table planted on a mutable search path gets written to instead;
  it is also what Supabase's own linter means by `function_search_path_mutable`.
- **`anon` is explicitly revoked**, not merely left without a policy. Every policy is
  `to authenticated` and scoped to `auth.uid()`.

### Verified, not asserted

There is no Docker on this machine, so `supabase start` and `supabase db lint --local`
cannot run (`db lint` also needs the `plpgsql_check` extension, which Homebrew's
PostgreSQL does not ship). The migration was instead applied for real against a local
PostgreSQL 17 with a small stub for the parts Supabase supplies (`auth.users`,
`auth.uid()`, the `anon` / `authenticated` / `service_role` roles):

```
0001_init.sql   65 statements, applied clean
seed.sql        applied clean, and again — idempotent
RLS enabled on  charities, charity_votes, library, notes, profiles, reading_progress  (6/6)
```

and exercised: the `on_auth_user_created` trigger creates the profile and its
`reading_progress` row; a non-hash `apple_sub_hash` is rejected; a second *active* vote is
rejected while the withdrawn one stays; a malformed verse key is rejected; re-saving a
library key is idempotent; `updated_at` moves on update; `streak_longest >= streak_current`
and the 780-byte bitset size are enforced; user A sees exactly their own rows and user B
sees none of them; an insert onto another profile fails with `insufficient_privilege`; and
`charity_tallies` still reports the full two-vote total to a caller who can see only one of
those votes. `anon` is denied on `public.charities`.

Independently parsed with `pgsql-parser` (libpg_query): 66 statements across the two files,
0 parse failures.

## What the owner has to do — each of these needs their login

```bash
supabase login                                   # opens a browser; owner only, once
# Dashboard -> New project ("scroll-the-quran"), pick a region, save the DB password
supabase link --project-ref <ref>                # <ref> is in the project URL / Settings -> General
supabase db push                                 # applies migrations/0001_init.sql
supabase db push --include-seed                  # or: psql "$DB_URL" -f supabase/seed.sql
```

Then Dashboard → Project Settings → API: copy `Project URL` and the `anon` `public` key
into `supabase/.env` (from `.env.example`). The `service_role` key never leaves the
dashboard and never goes into the app — it bypasses every policy in the migration.

Sanity check after the push, in the SQL editor:

```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public' order by 1;
-- every row must read true
```

## Sign in with Apple → Supabase Auth

The app already has the native flow: `FeatureOnboarding/Screens/SignInSheet.swift` runs
`ASAuthorizationController` and hands `OnboardingModel.signedInWithApple(...)` the
credential, which today is stored on device and goes nowhere. Wiring it to Supabase is a
change at that one call site plus a nonce on the request.

**Native, not web.** Do not use `signInWithOAuth` — that opens a browser. The native
credential's identity token goes to `signInWithIdToken`, which is why `skip_nonce_check`
must stay `false`.

1. **Apple Developer** → Certificates, Identifiers & Profiles:
   - The App ID `com.quranscroller.app` needs the **Sign in with Apple** capability.
   - Keys → **+** → Sign in with Apple → download the `.p8` **once**. Note the Key ID and
     your Team ID.
   - A **Services ID** is only needed if a web sign-in is ever added. The native iOS flow
     authenticates against the bundle id.
2. **Supabase Dashboard** → Authentication → Sign In / Providers → **Apple**: enable it,
   and put `com.quranscroller.app` in **Client IDs** (it is a comma-separated list; add
   the Services ID too if you made one). Fill the Secret Key fields from the `.p8`, Key ID
   and Team ID. `config.toml`'s `[auth.external.apple]` block mirrors this for local dev
   only — the hosted project reads the dashboard, not the file.
3. **In the app**, the nonce flow, which is the part that is easy to get subtly wrong:

   ```swift
   // 1. A random nonce, kept for step 3.
   let rawNonce = UUID().uuidString                      // or 32 bytes of SecRandomCopyBytes
   // 2. Apple is asked to sign the SHA-256 of it.
   request.nonce = SHA256.hash(data: Data(rawNonce.utf8))
       .map { String(format: "%02x", $0) }.joined()
   // 3. Supabase is handed the token plus the RAW nonce, and checks that hashing it
   //    reproduces the `nonce` claim inside the token.
   try await supabase.auth.signInWithIdToken(
       credentials: .init(
           provider: .apple,
           idToken: String(decoding: credential.identityToken!, as: UTF8.self),
           nonce: rawNonce
       )
   )
   ```

   Hash going out, raw coming back. Send the raw nonce to Apple, or the hash to Supabase,
   and the check fails with a message that does not say which half was wrong.
4. **`apple_sub_hash`** is computed on the device — `SHA256(credential.user)`, lowercase
   hex — and passed as user metadata so `handle_new_user` can store it:
   `data: ["apple_sub_hash": .string(hash)]`. The raw `credential.user` stays on the
   device. Apple only returns `fullName` and `email` on the **first** authorisation for
   that Apple Account, so capture them then or not at all.
5. **Deleting an account.** `delete from auth.users where id = ...` (service role, from an
   Edge Function) cascades through `profiles` and every child table — `on delete cascade`
   all the way down. App Store Review Guideline 5.1.1(v) requires an in-app delete path
   for any app that creates an account, so this becomes mandatory the day sync ships.

## Before this goes live

The day the app makes its first request to Supabase, the app stops being "collects no
data" and three things must change **in the same release**. Shipping the sync without
them is a privacy-manifest mismatch and an App Review rejection.

1. **`App/PrivacyInfo.xcprivacy`** — `NSPrivacyCollectedDataTypes` is empty today. It gains
   entries for what actually leaves the device, each **linked to the user** and used for
   **App Functionality** only, tracking `false`:
   - `NSPrivacyCollectedDataTypeUserID` — the Supabase user id and `apple_sub_hash`.
   - `NSPrivacyCollectedDataTypeEmailAddress` — only if you store the email; if the user
     used Apple's relay you still hold an address, so it still counts. Easiest honest
     answer is not to store it at all.
   - `NSPrivacyCollectedDataTypeOtherUserContent` — notes.
   - `NSPrivacyCollectedDataTypeOtherUsageData` — library, reading progress, streaks, votes.
2. **App Store Connect → App Privacy** — `docs/store/metadata.md` §3.1 flips from "No" to
   "Yes", with the same four categories, all "linked to you", all "App Functionality", and
   "Used for Tracking" **No**. §3.1's supporting paragraphs ("zero network calls", "there is
   no server we control") have to be rewritten, not just re-answered.
3. **`docs/store/metadata.md` §3.2 and `web/privacy.html`** — the policy currently says
   "does not collect your data", "no servers", "makes no network requests", "nowhere to
   send it" and "there is nothing for us to show you, correct, export or delete". All of
   that becomes false at once. The rewrite needs: what is stored server-side and why, who
   the processor is (Supabase, and its region), how long it is kept, how to export and
   delete it, and the in-app delete path from step 5 above. Bump "Last updated" on both.
   They are two copies of one text — `web/README.md` says to keep them in step.

Also worth doing before the first user: turn on **Point-in-Time Recovery** (paid tier),
decide the project **region** with your users in mind, and check
`Advisors → Security` in the dashboard, which runs the same lints as `supabase db lint`.
