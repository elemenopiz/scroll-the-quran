-- Scroll the Quran — v1 sync backend.
--
-- NOTHING IN THE SHIPPED APP TALKS TO THIS YET. CLAUDE.md rule 9 ("no network calls in
-- the app") still holds and the App Privacy answer is still "no data collected". This
-- schema is the scaffold for the day the owner decides to sync; the day it is switched
-- on, `supabase/README.md` lists the privacy-manifest, App Privacy and privacy-policy
-- changes that must land in the same release.
--
-- Shape of the thing:
--   auth.users            Supabase Auth, populated by Sign in with Apple
--     -> public.profiles  one row per user, id = auth.users.id, created by a trigger
--          -> library            saved verses and study passages
--          -> notes              one private note per verse
--          -> charity_votes      at most one *active* vote per profile
--          -> reading_progress   exactly one row per profile
--
-- The Apple user identifier itself is never stored. `apple_sub_hash` is a hash of it
-- computed on the device (see README), so a database dump cannot be joined back to an
-- Apple account. It exists only so an account can be recognised after a reinstall if the
-- user is signed in; it is nullable, because signing in is optional.
--
-- Every table has RLS enabled and every policy is scoped to `auth.uid()`. There is no
-- policy that lets one user read another user's rows; the only cross-user surface is the
-- `charity_tallies` view, which is aggregate-only.

set check_function_bodies = off;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
    id              uuid primary key references auth.users (id) on delete cascade,
    apple_sub_hash  text unique,
    display_name    text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    constraint profiles_display_name_length check (display_name is null or char_length(display_name) <= 64),
    -- Hex SHA-256, lower case: 64 characters. Rejects a raw Apple `sub` being written here
    -- by mistake, which is the whole point of the column being a hash.
    constraint profiles_apple_sub_hash_format check (apple_sub_hash is null or apple_sub_hash ~ '^[0-9a-f]{64}$')
);

comment on table public.profiles is
    'One row per authenticated user. id mirrors auth.users.id; apple_sub_hash is a device-computed SHA-256 of the Apple user identifier, never the identifier itself.';

alter table public.profiles enable row level security;

create policy "profiles: read own"
    on public.profiles for select
    to authenticated
    using (auth.uid() = id);

create policy "profiles: insert own"
    on public.profiles for insert
    to authenticated
    with check (auth.uid() = id);

create policy "profiles: update own"
    on public.profiles for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

create policy "profiles: delete own"
    on public.profiles for delete
    to authenticated
    using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- library — saved verses and study passages
-- ---------------------------------------------------------------------------

-- Mirrors the app's own vocabulary: a verse key is "2:255", a passage key is "94:5-6".
create type public.library_kind as enum ('verse', 'passage', 'study');

create table public.library (
    id          uuid primary key default gen_random_uuid(),
    profile_id  uuid not null references public.profiles (id) on delete cascade,
    key         text not null,
    kind        public.library_kind not null default 'verse',
    created_at  timestamptz not null default now(),
    -- "2:255" or "94:5-6"; the app's key grammar, enforced here so a malformed key cannot
    -- be synced up and then fail to resolve on another device.
    constraint library_key_format check (key ~ '^[0-9]{1,3}:[0-9]{1,3}(-[0-9]{1,3})?$'),
    constraint library_unique_per_profile unique (profile_id, key, kind)
);

comment on table public.library is
    'Saved verse ("2:255") and passage ("94:5-6") keys per profile. Unique per (profile, key, kind) so a re-save is idempotent.';

create index library_profile_created_idx on public.library (profile_id, created_at desc);

alter table public.library enable row level security;

create policy "library: read own"
    on public.library for select
    to authenticated
    using (auth.uid() = profile_id);

create policy "library: insert own"
    on public.library for insert
    to authenticated
    with check (auth.uid() = profile_id);

create policy "library: update own"
    on public.library for update
    to authenticated
    using (auth.uid() = profile_id)
    with check (auth.uid() = profile_id);

create policy "library: delete own"
    on public.library for delete
    to authenticated
    using (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- notes — one private note per verse
-- ---------------------------------------------------------------------------

create table public.notes (
    id          uuid primary key default gen_random_uuid(),
    profile_id  uuid not null references public.profiles (id) on delete cascade,
    verse_key   text not null,
    body        text not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    constraint notes_verse_key_format check (verse_key ~ '^[0-9]{1,3}:[0-9]{1,3}(-[0-9]{1,3})?$'),
    constraint notes_body_length check (char_length(body) <= 20000),
    constraint notes_unique_per_verse unique (profile_id, verse_key)
);

comment on table public.notes is
    'Private per-verse notes. Never readable by another user: there is no policy that selects a row whose profile_id is not auth.uid().';

create index notes_profile_updated_idx on public.notes (profile_id, updated_at desc);

alter table public.notes enable row level security;

create policy "notes: read own"
    on public.notes for select
    to authenticated
    using (auth.uid() = profile_id);

create policy "notes: insert own"
    on public.notes for insert
    to authenticated
    with check (auth.uid() = profile_id);

create policy "notes: update own"
    on public.notes for update
    to authenticated
    using (auth.uid() = profile_id)
    with check (auth.uid() = profile_id);

create policy "notes: delete own"
    on public.notes for delete
    to authenticated
    using (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- charities and charity_votes
-- ---------------------------------------------------------------------------

-- The catalogue the app bundles in Content/charities.json, mirrored so a vote has
-- something to reference. Read-only to every signed-in user; only the service role writes
-- it (there is no insert/update/delete policy, and RLS denies what it does not allow).
create table public.charities (
    id          text primary key,
    name        text not null,
    focus       text not null,
    url         text,
    founded     integer,
    -- Artwork slug, matching CharityArtwork.slugs in FeatureCommunity.
    image       text,
    sort_order  integer not null default 0,
    active      boolean not null default true,
    created_at  timestamptz not null default now()
);

comment on table public.charities is
    'Mirror of Content/charities.json. Readable by any signed-in user; writable only by the service role (no write policy exists).';

alter table public.charities enable row level security;

create policy "charities: read all"
    on public.charities for select
    to authenticated
    using (active);

create table public.charity_votes (
    id          uuid primary key default gen_random_uuid(),
    profile_id  uuid not null references public.profiles (id) on delete cascade,
    charity_id  text not null references public.charities (id) on delete restrict,
    voted_at    timestamptz not null default now(),
    -- A vote is superseded rather than deleted, so the history survives while exactly one
    -- row per profile stays current. The partial unique index below is what enforces
    -- "one active vote per profile".
    withdrawn_at timestamptz,
    constraint charity_votes_withdrawn_after_vote check (withdrawn_at is null or withdrawn_at >= voted_at)
);

comment on table public.charity_votes is
    'One active vote per profile, enforced by charity_votes_one_active_idx. Superseding a vote sets withdrawn_at on the old row rather than deleting it.';

create unique index charity_votes_one_active_idx
    on public.charity_votes (profile_id)
    where withdrawn_at is null;

create index charity_votes_charity_idx on public.charity_votes (charity_id) where withdrawn_at is null;

alter table public.charity_votes enable row level security;

create policy "charity_votes: read own"
    on public.charity_votes for select
    to authenticated
    using (auth.uid() = profile_id);

create policy "charity_votes: insert own"
    on public.charity_votes for insert
    to authenticated
    with check (auth.uid() = profile_id);

create policy "charity_votes: update own"
    on public.charity_votes for update
    to authenticated
    using (auth.uid() = profile_id)
    with check (auth.uid() = profile_id);

create policy "charity_votes: delete own"
    on public.charity_votes for delete
    to authenticated
    using (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- reading_progress — exactly one row per profile
-- ---------------------------------------------------------------------------

create table public.reading_progress (
    profile_id      uuid primary key references public.profiles (id) on delete cascade,
    -- 6,236 verses -> a 780-byte bitset, one bit per global verse index
    -- (surah.startIndex + ayah - 1). Nullable so a client that only syncs counters can.
    read_bitset     bytea,
    read_count      integer not null default 0,
    streak_current  integer not null default 0,
    streak_longest  integer not null default 0,
    last_read_on    date,
    updated_at      timestamptz not null default now(),
    constraint reading_progress_read_count_range check (read_count between 0 and 6236),
    constraint reading_progress_streaks_nonnegative check (streak_current >= 0 and streak_longest >= 0),
    constraint reading_progress_longest_ge_current check (streak_longest >= streak_current),
    -- ceil(6236 / 8) = 780
    constraint reading_progress_bitset_size check (read_bitset is null or octet_length(read_bitset) = 780)
);

comment on table public.reading_progress is
    'One row per profile. read_bitset is 780 bytes, one bit per global verse index (surah.startIndex + ayah - 1) across the 6,236 ayat.';

alter table public.reading_progress enable row level security;

create policy "reading_progress: read own"
    on public.reading_progress for select
    to authenticated
    using (auth.uid() = profile_id);

create policy "reading_progress: insert own"
    on public.reading_progress for insert
    to authenticated
    with check (auth.uid() = profile_id);

create policy "reading_progress: update own"
    on public.reading_progress for update
    to authenticated
    using (auth.uid() = profile_id)
    with check (auth.uid() = profile_id);

create policy "reading_progress: delete own"
    on public.reading_progress for delete
    to authenticated
    using (auth.uid() = profile_id);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

comment on function public.touch_updated_at() is
    'BEFORE UPDATE trigger: stamps updated_at. Not SECURITY DEFINER — it needs no privileges the writer does not already have.';

create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

create trigger notes_touch_updated_at
    before update on public.notes
    for each row execute function public.touch_updated_at();

create trigger reading_progress_touch_updated_at
    before update on public.reading_progress
    for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- handle_new_user
-- ---------------------------------------------------------------------------

-- Runs as the definer because it writes to public.profiles from the auth schema's own
-- trigger, where auth.uid() is not yet the new user. `search_path` is pinned to '' and
-- every name below is schema-qualified: without that, a table planted on a mutable
-- search_path could be written to instead (CVE-shaped, and the reason Supabase's own
-- linter flags function_search_path_mutable).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, apple_sub_hash, display_name)
    values (
        new.id,
        nullif(new.raw_user_meta_data ->> 'apple_sub_hash', ''),
        nullif(new.raw_user_meta_data ->> 'full_name', '')
    )
    on conflict (id) do nothing;

    insert into public.reading_progress (profile_id)
    values (new.id)
    on conflict (profile_id) do nothing;

    return new;
end;
$$;

comment on function public.handle_new_user() is
    'AFTER INSERT on auth.users: creates the profile and its empty reading_progress row. apple_sub_hash is read from raw_user_meta_data, where the client puts the hash it computed on device.';

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- charity_tallies — the Community tab's aggregate
-- ---------------------------------------------------------------------------

-- A plain view over charity_votes cannot work here, in either direction. With
-- `security_invoker = on` the RLS policies above apply to the caller, so every user would
-- count exactly one vote -- their own. With it off, the view runs as its owner and hands
-- the caller a way to read past RLS, one carefully chosen filter at a time.
--
-- So the aggregation happens inside a SECURITY DEFINER function whose *return type* is the
-- privacy boundary: it emits (charity_id, votes) and nothing else, with no argument to
-- narrow it by, so there is no question to ask it that reveals an individual vote. The
-- view then joins those totals onto the charity catalogue with invoker rights.
create or replace function public.charity_tally_rows()
returns table (charity_id text, votes bigint)
language sql
stable
security definer
set search_path = ''
as $$
    select v.charity_id, count(*)::bigint
    from public.charity_votes v
    where v.withdrawn_at is null
    group by v.charity_id;
$$;

comment on function public.charity_tally_rows() is
    'Definer-rights aggregate over charity_votes. Returns only (charity_id, votes) -- no profile_id ever leaves this function, so a caller learns the totals and nothing about who voted.';

create or replace view public.charity_tallies
with (security_invoker = on) as
    select
        c.id            as charity_id,
        c.name,
        c.focus,
        c.image,
        c.sort_order,
        coalesce(t.votes, 0)::bigint as votes,
        case
            when sum(coalesce(t.votes, 0)) over () = 0 then 0::numeric
            else round(coalesce(t.votes, 0)::numeric * 100 / sum(coalesce(t.votes, 0)) over (), 1)
        end as share_percent
    from public.charities c
    left join public.charity_tally_rows() t on t.charity_id = c.id
    where c.active
    order by votes desc, c.sort_order asc, c.name asc;

comment on view public.charity_tallies is
    'What the Community tab reads: one row per active charity with its vote count and share. Individual votes are invisible -- the counts come from the definer-rights charity_tally_rows().';

revoke all on public.charity_tallies from anon;
grant select on public.charity_tallies to authenticated;
revoke all on function public.charity_tally_rows() from anon, public;
grant execute on function public.charity_tally_rows() to authenticated;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- A hosted Supabase project has `alter default privileges ... grant all on tables to
-- postgres, anon, authenticated, service_role` in the public schema, so these grants
-- would mostly happen anyway. They are written out because "mostly" is not a security
-- posture: this way the migration says what each role may do, it does the same thing on
-- a plain PostgreSQL, and `anon` is explicitly cut off rather than merely blocked by the
-- absence of a policy.
--
-- RLS is what actually confines a row to its owner. These grants only decide which verbs
-- are on the table at all.

revoke all on all tables in schema public from anon;

grant select, insert, update, delete on
    public.profiles,
    public.library,
    public.notes,
    public.charity_votes
    to authenticated;

-- The catalogue is read-only to users; only the service role (which bypasses RLS) seeds it.
grant select on public.charities to authenticated;

grant select, insert, update on public.reading_progress to authenticated;
