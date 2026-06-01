# iOS release checklist — Ring Knot

A pre-TestFlight checklist. This phase delivers ship-readiness hygiene; the items
that still require an Apple Developer account / signing are called out as
**[needs account]**.

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
