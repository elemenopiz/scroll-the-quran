-- Seed data: the charity catalogue.
--
-- `supabase db reset` runs this after the migrations. The three organisations, their ids,
-- names, focus lines, URLs, founding years and artwork slugs are copied from
-- `Content/charities.json`, which is what `FeatureCommunity/CharityCatalog.swift` decodes
-- and what the Community tab renders from. If the JSON changes, change this to match --
-- nothing automates it, and a charity_votes row references public.charities(id) with
-- `on delete restrict`, so an id that drifts here cannot be voted for there.
--
-- `on conflict do update` rather than `do nothing`: re-running the seed should correct a
-- stale name or URL, not silently keep the old one.

insert into public.charities (id, name, focus, url, founded, image, sort_order, active)
values
    ('islamic-relief', 'Islamic Relief Worldwide', 'Emergency relief and development', 'https://islamic-relief.org',    1984, 'giving-hands',  0, true),
    ('penny-appeal',   'Penny Appeal',             'Water, orphan care, food',         'https://pennyappeal.org',       2009, 'clean-water',   1, true),
    ('human-appeal',   'Human Appeal',             'Health, education, livelihoods',   'https://humanappeal.org.uk',    1991, 'harvest-wheat', 2, true)
on conflict (id) do update
set name       = excluded.name,
    focus      = excluded.focus,
    url        = excluded.url,
    founded    = excluded.founded,
    image      = excluded.image,
    sort_order = excluded.sort_order,
    active     = excluded.active;
