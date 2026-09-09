# Phase 2c — DesignSystem components
Owns: `Packages/ScrollKit/Sources/DesignSystem/Components/**`, `Sources/DesignSystem/Gallery/**`, `Tests/DesignSystemTests`, `Reference/manifest.json` (may append probe notes only).

Deliver components, each with `#Preview` light+dark and a small test where logic exists:
`PrimaryPillButton` (black/white pill, 60pt, bold), `OutlinePillButton`, `CapsuleIconGroup` (grouped icon pills like `[dice][heart]`), `Chip` (theme chip), `CapsLabel(icon:text:)` (11pt caps, tracking), `TintedSectionBox(kind: .quote/.historical/.life/.dyk/.apply)`, `SheetHeader(title:leading:trailing:)`, `CardContainer(radius:)`, `ProgressBar`, `StarRow(rating:)`, `ReviewCard` (yellow left border), `WheelPicker3`, `TimelineStep` (paywall circle+line), `PlanCard` (image + START HERE ribbon), `StatCard` (streak/progress), `RowLink` (icon + title + subtitle + chevron), `ActionIconRow` (bookmark/comment/share/check), `ToastHint`, `PhoneFrame` (device mockup for onboarding).
`ComponentGallery` screen reachable via `--screenshot gallery`, sectioned, both appearances.
Match the references by measuring: heights, radii, paddings in pt (reference px ÷ 3). Document measured values in `Components/README.md`.
DoD: `swift test --filter DesignSystemTests` green; `Tools/verify.sh --snap gallery` produces a PNG with no layout warnings in the console; `swiftlint` clean.
