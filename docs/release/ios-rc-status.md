# iOS release-candidate status

**Generated for Phase 5A — full app integrated into `main`.**

## Snapshot

| Field | Value |
| --- | --- |
| Branch | `main` |
| Integration commit | `98583dc` (merge of PR #4 — "ship Ring Knot iOS release candidate") |
| Marketing version | **1.0.0** (`CFBundleShortVersionString`) |
| Build number | **1** (`CFBundleVersion`) |
| Bundle ID | `com.swarpfoundation.ringknot` |
| Levels | 20 |
| Simulator destination | iPhone 17 Pro (iOS latest); layout also checked on iPhone 17e |

## Status

| Check | Status |
| --- | --- |
| Asset verification (`verify_assets.sh`) | ✅ pass (assets regenerate deterministically — no drift) |
| Replay validator self-test | ✅ pass |
| Replay validator — all 20 levels | ✅ pass |
| `xcodegen generate` | ✅ pass |
| Debug build | ✅ pass |
| Debug tests (38 unit + UI) | ✅ pass (0 failures) |
| Release build | ✅ pass |
| `bash tools/ci_local.sh` (from clean `main`) | ✅ **CI PASSED** |
| Privacy manifest in built `.app` | ✅ present (`PrivacyInfo.xcprivacy`) |
| AppIcon configured | ✅ present (icons + `Assets.car`) |
| Release DEBUG-bridge scan | ✅ none (no `bridge.*` / `TestBridgeOverlay` / `uiTest*` strings) |
| Analytics / ads / Firebase | ✅ none (`otool -L` = Apple system frameworks only) |
| Network domains | ✅ none (no app-owned `http(s)://` strings) |
| Copied / reference / ad assets | ✅ none in `shared/assets` |
| Encryption beyond Apple standard libs | ✅ none (`ITSAppUsesNonExemptEncryption = false`) |

## Known limitations

- **Physical-device QA not run** — the only paired iPhone was offline and signing
  is owner-needed (simulator-only project). See `physical-device-qa-results.md`.
- **No `.mov` demo recording on this host** — the simulator `recordVideo` render
  server failed repeatedly with `SimRenderServer.SimulatorError Code=2`. Eight
  genuine stills in `docs/screenshots/final-ios/` are the evidence; the recording
  driver (`tools/capture_phase4b_demo.sh`) is kept for a stable host.
- **Onboarding title** can clip slightly at the largest widths/centering
  (cosmetic; text remains readable and the page scrolls).
- **Rotation gesture coverage** — release is covered by real-gesture XCUITests; the
  circular rotate-to-align is bridge-driven (raw circular drags around a SpriteKit
  node are not a stable XCUITest primitive).
- TestFlight/App Store steps are **owner-needed** (Team ID, signing, App Store
  Connect record, metadata, questionnaires) — see `testflight-owner-checklist.md`.

## Ready for owner physical-device QA?

**Yes.** The app builds, the full automated suite passes from clean `main`, and the
Release artifact is clean. The only thing standing between this and a device/
TestFlight build is **owner-supplied signing + App Store Connect setup**. Hand the
owner `testflight-owner-checklist.md` and run the device pass in
`physical-device-qa-results.md` once signing is configured.
