# iOS release checklist — Ring Knot

A pre-TestFlight checklist. This phase delivers ship-readiness hygiene; the items
that still require an Apple Developer account / signing are called out as
**[needs account]**.

## Release-candidate status (Phase 4B)

| Area | Status | Notes |
| --- | --- | --- |
| Local CI gate (`ci_local.sh`) | **done** | assets, validator, Debug build, unit+UI tests, Release build |
| Rotatable-ring mechanic + tuning | **done** | values in `docs/gameplay/rotatable-rings.md` |
| Real-gesture coverage | **done** | `RingKnotRealGestureUITests` (pull-refuse + aligned-release) |
| Privacy manifest in app bundle | **done** | `PrivacyInfo.xcprivacy`, verified in built `.app` |
| No ads / analytics / Firebase / backend / accounts / IAP / network | **done** | dependency + string scan, see below |
| DEBUG bridge excluded from Release | **done** | Release build + `nm`/`strings` scan |
| App icon configured | **done** | `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` |
| Small-device layout check | **done** | iPhone 17e simulator launch + screenshots |
| Genuine screenshots / evidence | **done** | `docs/screenshots/phase-4a-*` + `phase-4b-*` |
| Physical-device pass | **owner-needed** | signing required; see `docs/physical-device-qa.md` |
| Distribution signing (`DEVELOPMENT_TEAM`) | **owner-needed** | currently empty / simulator-only |
| App Store Connect record + metadata | **owner-needed** | description, keywords, support URL, age rating |
| App Privacy questionnaire | **owner-needed** | confirm "Data Not Collected" |
| TestFlight upload | **blocked** (by signing) | not part of this phase by design |

### Owner-needed values (do not invent these)

- Apple Developer **Team ID** → `DEVELOPMENT_TEAM`
- Distribution **signing certificate / profile** (Automatic or manual)
- **App Store Connect** app record (bundle id `com.swarpfoundation.ringknot`)
- **Support URL** and marketing/privacy URLs
- **App description**, keywords, age rating, category
- **Final marketing screenshots** at required device sizes
- **Privacy questionnaire** confirmation ("Data Not Collected")

### Release artifact safety scan (Phase 4B)

Run against a Release build of `RingKnot.app` (e.g. `-configuration Release
-derivedDataPath /tmp/rcdd build`):

- [x] `PrivacyInfo.xcprivacy` present in the built `.app`.
- [x] App icon present (`AppIcon*` PNGs + `Assets.car`).
- [x] **No** DEBUG bridge strings in the binary — `strings RingKnot | grep -iE
  'bridge\.(nextMove|invalidMove|rotateAligned|rotateMisaligned|tryRelease|rotationMove)|TestBridgeOverlay|uiTest'`
  returns nothing (the `#if DEBUG` overlay/actions are compiled out).
- [x] No app-owned network URLs — `strings` shows no `http(s)://` beyond system
  framework boilerplate.
- [x] No analytics / ads / Firebase — `otool -L` lists only Apple system
  frameworks (Foundation, AVFAudio, Combine, CoreGraphics, CoreHaptics, SpriteKit,
  SwiftUI, UIKit). No third-party Swift packages.

## Build & correctness gate

- [x] `bash tools/ci_local.sh` passes end to end:
  - [x] generated assets verified
  - [x] replay validator self-test + all 20 levels replay to completion
  - [x] `xcodegen generate` succeeds
  - [x] Debug build succeeds
  - [x] unit + UI tests pass
  - [x] Release build succeeds (DEBUG test bridge excluded)
- [x] No third-party Swift packages linked.
- [x] No network calls, analytics, ads, Firebase, backend, accounts, or IAP.

## Privacy & compliance

- [x] `PrivacyInfo.xcprivacy` is in the app target and lands in the built
  `.app` bundle (verified in `Debug-iphonesimulator/RingKnot.app`).
- [x] `NSPrivacyTracking` = `false`, tracking domains empty, no collected data.
- [x] Required-reason API audit — only `UserDefaults` (`CA92.1`); see
  `docs/privacy.md`.
- [x] `ITSAppUsesNonExemptEncryption` = `false` in Info.plist (no custom crypto).
- [ ] **[needs account]** Confirm the App Privacy questionnaire in App Store
  Connect reflects "Data Not Collected".

## App configuration

- [x] `CFBundleDisplayName` = "Ring Knot".
- [x] `CFBundleShortVersionString` / `CFBundleVersion` set (1.0.0 / 1).
- [x] Portrait-only on iPhone; portrait + upside-down on iPad.
- [x] Launch screen configured (`LaunchBackground` + brand mark).
- [x] App icon set (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`).
- [ ] **[needs account]** `DEVELOPMENT_TEAM` and a distribution signing identity.
- [ ] **[needs account]** Archive with a Release scheme and upload to TestFlight.

## Accessibility

- [x] VoiceOver labels on navigation, level cards, HUD (Back/Restart/Hint/Moves),
  onboarding, settings, and the SpriteKit board (summary + custom actions).
- [x] Level cards announce locked / unlocked / completed, par, and best.
- [x] Dynamic Type supported (scrolling onboarding, adaptive level grid).
- [x] Reduce Motion honoured (no particles/shake, simplified effects, static
  tutorial highlight).
- [x] Board summary names the held ring's alignment; "Rotate ring to opening"
  custom action aligns the next solvable ring without a gesture.
- [ ] Manual VoiceOver sweep on a physical device (incl. the rotation action;
  recommended before submission).

## Content & QA

- [x] Onboarding shows once, re-openable from Settings (rotation-mechanic copy).
- [x] Level 1 tutorial uses the solution path (no hard-coded ring ids) and teaches
  rotate → pull → clear blockers.
- [x] Rotatable rings: every ring starts misaligned, snaps + glows when aligned,
  refuses a pull before alignment, and only counts a move on release
  (`docs/gameplay/rotatable-rings.md`).
- [x] `python3 tools/replay_validator.py` passes the rotation-aware replay for all
  20 levels.
- [x] Settings: Sound, Haptics, Replay onboarding, Replay tutorial, Reset
  progress (with confirmation), credits note, version/build.
- [x] Completion screen shows moves/par/best, New Best, and "All Levels Complete"
  on level 20.
- [x] Genuine screenshots in `docs/screenshots/phase-3-*.png` and
  `docs/screenshots/phase-4a-*.png`.

## Store listing (later phase)

- [ ] **[needs account]** Marketing screenshots at required device sizes.
- [ ] **[needs account]** Description, keywords, support URL, age rating.
- [ ] **[needs account]** Export compliance answers.

## Phase 6A gate (anchors & blocker clips)

- [x] Every level has ≥1 closed anchor; complexity curve holds (replay validator).
- [x] Every dependency has a visual interlock/clip; no `abstractOnly` in the pack.
- [x] Clips/anchors drawn procedurally — no downloaded or copied art.
- [x] DEBUG-only `-uiTestUnlockAll` is gated out of Release (artifact scan).
- [x] Genuine `phase-6a-*` screenshots captured on iPhone 17 Pro simulator.

## Phase 6B gate (interlock geometry & art)

- [x] Backward-compatible clip/interlock fields; Phase 6A JSON still loads.
- [x] Every dependency has a non-decorative interlock; no abstractOnly in the pack.
- [x] Clamps drawn procedurally (bevel/rivets/contact shadow) — no copied art.
- [x] Background remains original/subtle — no copied reference equation/hand/UI.
- [x] DEBUG `bridge.tryReleaseBlocked` excluded from Release (artifact scan).
- [x] Genuine `phase-6b-*` screenshots on iPhone 17 Pro simulator.
