# Phase 3d — Community tab (charity vote)
Owns: `Packages/ScrollKit/Sources/FeatureCommunity/**`, `Tests/FeatureCommunityTests/**`, `Content/charities.json` (edit), `UITests/Specs/community-*.json`, `UITests/CommunityTests.swift`. Simulator: ONLY `ScrollSim-3d`.
Reference: `community-dark.png`.
`CommunityView`: green-gradient stat card (`GIVEN TO CHARITIES` caps, serif amount from charities.json `givenTotalUSD` formatted, divider, "Every subscription gives back."), serif "Vote Who We Give To", body copy, org cards (image from Artwork/charity-*.png once wired, name, tagline, Vote button → "Voted" state persisted in `Prefs.charityVote`, description, Learn more link). Light appearance derived.
DoD: snapshot `community-dark` < 0.10; vote persists across relaunch (UI test); `Tools/verify.sh --ui --snap community-dark` exits 0.
