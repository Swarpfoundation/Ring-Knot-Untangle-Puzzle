# Ring Knot — iOS Final Release Candidate Status (v1.0.0)

Status snapshot for the v1 release candidate after the Phase 6 gameplay/art stack
landed on `main`. Validated from a clean `main` checkout on the iPhone 17 Pro
simulator (iOS 26.4.1) — the only destination used throughout.

## Current main commit
- `0e00835` — *Merge pull request #9 from … ios-phase-6d-split-tube-masking*

## Merged PRs (Phase 6 stack)
| PR | Title | Merged into main |
|----|-------|------------------|
| #6 | feat(ios): add anchor rings and blocker clips | `e2497cf` |
| #7 | polish(ios): refine anchor blocker interlock visuals | `83f4999` |
| #8 | polish(ios): add tube occlusion interlock depth | `bc98cc1` |
| #9 | polish(ios): add split tube occlusion polish | `0e00835` |

Merge commits were used (no squash) so every phase commit (`5574a91`, `739a45c`,
`3e4042a`, `60f7b5f`) is preserved in `main` history. PR #5 (pre-Phase-6 RC docs)
was **closed as superseded**, not merged.

## Build status
- Debug build (iPhone 17 Pro simulator): **SUCCEEDED**
- Release build (iPhone 17 Pro simulator): **SUCCEEDED**
- XcodeGen project generates cleanly from `ios/RingKnot/project.yml`.

## Test status
- `bash tools/ci_local.sh`: **CI PASSED** (6/6 steps).
- 74 unit tests + the UI test suites: **0 failures**.

## Replay validator status
- `python3 tools/replay_validator.py --selftest`: **passed**.
- `python3 tools/replay_validator.py`: **20/20 levels replay**; every level has the
  band-minimum closed anchors, clips on anchors, non-decorative interlock per
  dependency, `bridgeBand` clips carry a contact ring, solution removable-only,
  anchors remain after replay.

## Asset verification status
- `bash tools/verify_assets.sh`: **29 passed, 0 failed** (art + SFX procedurally
  generated; no downloaded assets).

## Privacy manifest status
- `ios/RingKnot/RingKnot/Resources/PrivacyInfo.xcprivacy` present and bundled in the
  Release `.app`.

## Release artifact scan status (clean-main Release build)
- PrivacyInfo.xcprivacy: **present**
- AppIcon / Assets.car: **present**
- DEBUG bridge strings (`bridge.*`, `uiTestUnlockAll`, `tryReleaseBlocked`): **none**
- Analytics / ad / Firebase frameworks: **none**
- Linked libraries: **Apple system frameworks only**
- Unexpected network URLs: **none**
- Bundled level pack: **20 levels**, all with `closedAnchor` rings + `clips` +
  `interlocks`; **no level uses `abstractOnly`**; all 20 replay.

## Final gameplay status
- Rotate-then-pull mechanic intact: roll the open ring's gap to its exit, then pull.
- Closed **anchor** rings are fixed obstacles; **blocker clips** + **interlocks**
  explain every dependency; **bridge bands** span ring-to-ring contact; **split-tube
  over-arcs** make the copper knot weave over the silver bands.
- Completion ignores anchors; hints ignore anchors; move counter only increments on a
  successful removable-ring release.

## Version / build
- CFBundleShortVersionString = **1.0.0**
- CFBundleVersion = **1**
- CFBundleIdentifier = **com.swarpfoundation.ringknot**
- CFBundleDisplayName = **Ring Knot**
- ITSAppUsesNonExemptEncryption = **false**

## Archive status
- `xcodebuild … -configuration Release archive` **succeeded** and produced a device
  `arm64` `RingKnot.app`, **but the archive is unsigned** (`codesign -dv` →
  "code object is not signed at all") because the project sets
  `CODE_SIGNING_ALLOWED = NO` / empty `DEVELOPMENT_TEAM` for the hermetic
  simulator-only setup. It is therefore **not distributable / not uploadable** as-is.
  Signing was **not** hacked. The owner must set a real Team ID + signing to produce
  a distributable archive; no upload was performed. (The local archive was deleted —
  build artifacts are not committed.)

## Known limitations
See `docs/release/known-limitations-v1.md`. Summary: simulated split-tube occlusion
(not per-pixel masking); no screen recording from this headless simulator host;
physical-device QA pending; no Android.

## Owner-needed blockers (cannot be done without the owner / Apple account)
1. Apple Developer **Team ID** + signing certificate & provisioning profile.
2. App Store Connect **app record** for `com.swarpfoundation.ringknot`.
3. **Physical-device QA** signoff (no device available in this environment).
4. App Store metadata finalisation, age-rating questionnaire, export-compliance
   answers, and privacy questionnaire confirmation.
See `docs/release/testflight-owner-checklist.md` for the exact list.
