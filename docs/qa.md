# QA — Ring Knot iOS

This is the test and verification story for the iOS app. Everything here runs
locally with the system toolchain (Xcode + Python 3) — no network, no services.

## One command

```bash
bash tools/ci_local.sh
```

The pipeline fails fast with a clear message on the first broken step and dumps
the tail of the failing log. Steps:

1. **Verify generated assets** — `tools/verify_assets.sh` confirms the procedural
   art/SFX match their expected format (originality + hermetic-build guard).
2. **Replay validator** — `tools/replay_validator.py --selftest` then a full pack
   replay (see below).
3. **Regenerate the Xcode project** — `xcodegen generate`.
4. **Debug build** — `xcodebuild ... -configuration Debug build`.
5. **Debug test** — unit + UI tests.
6. **Release build** — confirms the `DEBUG`-only test bridge is excluded from a
   shipping configuration.

Override the simulator with `SIM_DEST='platform=iOS Simulator,name=...,OS=...'`.

## Replay validator

`tools/replay_validator.py` is a standard-library Python port of the in-app
`MoveValidator`. For **every** level in
`shared/levels/ring_unlock_level_pack_v1.json` it:

- rejects duplicate ring ids and invalid `exitDirection` values,
- checks that every `requires` dependency and every `solution` step references a
  ring that exists,
- asserts blocked rings (those with unmet prerequisites) are **not** removable
  before their prerequisites are cleared,
- replays the `solution` path in order — every step must be `accepted` —
- and asserts the level is fully cleared at the end.

`--selftest` runs synthetic levels that must each fail for a specific reason, so
the validator's own logic is verified before it is trusted on the real pack.

```bash
python3 tools/replay_validator.py --selftest   # validator logic
python3 tools/replay_validator.py               # all 20 shipped levels
```

The shared JSON is the source of truth; the validator never edits it. If a level
ever fails to replay, that is a data bug to fix in the JSON (and document), not a
reason to weaken the validator.

## Unit tests (`RingKnotTests`, 25 tests)

`@testable import RingKnot`, exercising the pure-Swift engine: JSON loading, all
loader validation errors, direction/cell parsing, dependency unlock logic,
invalid-move rejection, valid-move acceptance, full completion via the canonical
solution, persistence round-trips, all 20 levels solvable, and blocked rings not
removable early.

## UI tests (XCUITest)

State is made deterministic with `DEBUG` launch arguments handled in
`Preferences.applyUITestOverrides` and `AppEnvironment`:

| Argument | Effect |
| --- | --- |
| `-com.swarpfoundation.ringknot.resetProgress YES` | Reset the progress store |
| `-uiTestSkipIntro YES` | Mark onboarding + tutorial complete |
| `-uiTestResetIntros YES` | Re-arm onboarding (and tutorial) |
| `-uiTestResetTutorial YES` | Skip onboarding, re-arm the Level 1 tutorial |
| `-uiTestSoundOff YES` | Start with Sound off |
| `-uiTestBridge YES` | Show the `DEBUG`-only deterministic move bridge |

**`RingKnotUITests` (7 tests)** — launch-to-home, Play opens Level Select, open
Level 1, valid move increments the counter, invalid move is rejected, hint
survives, completion UI appears. These launch with intros skipped so they land
straight on Home.

**`RingKnotPhase3UITests` (9 tests)** — onboarding appears and completes,
onboarding Skip goes to Home, Settings opens from Home, the Sound toggle persists
across a relaunch, the Level 1 tutorial appears, Hint works, the completion
screen shows moves/par/best/New Best, Level 2 is unlocked after Level 1, and
Reset Progress re-shows onboarding.

### The DEBUG test bridge

`GameView` includes a `TestBridgeOverlay` guarded by `#if DEBUG` and only rendered
when launched with `-uiTestBridge`. It exposes two off-screen buttons
(`bridge.nextMove`, `bridge.invalidMove`) that drive deterministic moves without
simulating drags on the SpriteKit board. Because it is `#if DEBUG`, it is compiled
out of Release builds — step 6 of `ci_local.sh` (a Release build) is the guard
that proves it cannot leak into a shipping binary.

## Screenshots

`ScreenshotTour.test_capturePhase3Screens` navigates each screen with the
appropriate intro state and attaches a screenshot. To regenerate the six images
in `docs/screenshots/phase-3-*.png`:

```bash
xcodebuild -project ios/RingKnot/RingKnot.xcodeproj -scheme RingKnot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -configuration Debug test \
  -only-testing:RingKnotUITests/ScreenshotTour/test_capturePhase3Screens \
  -resultBundlePath /tmp/ss.xcresult
xcrun xcresulttool export attachments --path /tmp/ss.xcresult --output-path /tmp/ss_att
# then copy the phase-3-* attachments (see manifest.json) into docs/screenshots/
```
