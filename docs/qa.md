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
`MoveValidator`, including the Phase 4A rotation rules. For **every** level in
`shared/levels/ring_unlock_level_pack_v1.json` it:

- rejects duplicate ring ids and invalid `exitDirection` values,
- validates `alignmentToleranceDegrees` and every ring's `initialGapAngle`
  (finite; falling back to a derived, non-aligned angle if absent),
- asserts no ring starts already aligned (the mechanic requires a deliberate roll),
- checks that every `requires` dependency and every `solution` step references a
  ring that exists,
- asserts blocked rings are **not** removable before their prerequisites — even
  with the gap aligned,
- replays the `solution` path in order: a pull at the ring's misaligned initial
  gap must be refused, then the gap is rolled onto the exit and the release must
  be `accepted`,
- and asserts the level is fully cleared at the end.

The shared JSON's rotation fields are written reproducibly by
`tools/apply_rotation_fields.py` (deterministic; re-running yields identical
numbers).

`--selftest` runs synthetic levels that must each fail for a specific reason, so
the validator's own logic is verified before it is trusted on the real pack.

```bash
python3 tools/replay_validator.py --selftest   # validator logic
python3 tools/replay_validator.py               # all 20 shipped levels
```

The shared JSON is the source of truth; the validator never edits it. If a level
ever fails to replay, that is a data bug to fix in the JSON (and document), not a
reason to weaken the validator.

## Unit tests (`RingKnotTests`, 38 tests)

`@testable import RingKnot`, exercising the pure-Swift engine: JSON loading, all
loader validation errors, direction/cell parsing, dependency unlock logic,
invalid-move rejection, valid-move acceptance, full completion via the canonical
solution, persistence round-trips, all 20 levels solvable, and blocked rings not
removable early.

`RingRotationTests` (13) cover the Phase 4A rotatable-ring mechanic: angle
normalization, shortest angular distance, alignment true/false (including
wrap-around), rotating through many whole turns without drift, the snap window,
`Direction.exitAngleDegrees`, every ring loading a misaligned `initialGapAngle`,
the tolerance bands, an unaligned ring being unreleasable, an aligned/unblocked
ring releasing (and counting exactly one move), an aligned-but-blocked ring still
blocked, rotation never counting as a move, and all 20 levels completing when each
ring is aligned before the pull.

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

**`RingKnotPhase4UITests` (6 tests)** — the Level 1 tutorial prompts to *rotate*
the ring, a pull before alignment does not remove the ring, rolling the gap into
alignment then pulling removes it and counts exactly one move (rotation alone
counts nothing), a hint on an unaligned ring keeps the HUD and counts no move, a
full rotate-then-pull move completes Level 1 and unlocks Level 2, and Settings →
"Replay Level 1 tutorial" re-arms the rotation tutorial.

### The DEBUG test bridge

`GameView` includes a `TestBridgeOverlay` guarded by `#if DEBUG` and only rendered
when launched with `-uiTestBridge`. It exposes off-screen buttons that drive
deterministic moves without simulating drags on the SpriteKit board:

| Button | Action |
| --- | --- |
| `bridge.nextMove` | Align + release the next solution ring (legacy completion hook) |
| `bridge.invalidMove` | Attempt a still-blocked ring (blocked feedback) |
| `bridge.rotateAligned` | Roll the next solution ring exactly onto its exit |
| `bridge.rotateMisaligned` | Roll it to a clearly misaligned angle |
| `bridge.tryRelease` | Pull at the current gap (removes only if aligned + unblocked) |
| `bridge.rotationMove` | Full rotate-then-pull move |

Because the overlay is `#if DEBUG`, it is compiled out of Release builds — step 6
of `ci_local.sh` (a Release build) is the guard that proves it cannot leak into a
shipping binary.

### Real gestures vs. the deterministic bridge

Coverage is split deliberately:

| Concern | Covered by |
| --- | --- |
| Pull a **misaligned** ring → no release (real touch) | `RingKnotRealGestureUITests.test40` — a real coordinate drag straight up on Level 1's first ring |
| Pull a bridge-**aligned** ring → real outward drag releases it | `RingKnotRealGestureUITests.test41` — bridge aligns, a real drag releases |
| Rotation alignment, move-counter semantics, blocked feedback, completion, unlock | `RingKnotPhase4UITests` via the bridge (deterministic) |

`RingKnotRealGestureUITests` reproduces the scene's layout maths from the
`game.board` element frame to land the drag on cell B3, and uses a **straight
radial** drag (constant bearing from the ring centre) so it isolates the *pull*
half of the gesture without adding rotation. Circular rotation itself stays
bridge-driven because raw circular drags around a SpriteKit node are not a stable
XCUITest primitive; the bridge is the deterministic oracle for the alignment
logic, and the real-gesture tests prove the pull/refuse path works under an actual
touch. Both real-gesture tests were confirmed stable across repeated runs.

### Small-device layout check

Main tests run on **iPhone 17 Pro** (1206×2622). Layout was also verified on the
smaller **iPhone 17e** (1170×2532) by running `test_capturePhase3Screens` there and
inspecting the captures:

- Gameplay HUD (Back / Level / Moves / Hint / Restart) sits above the board and
  does not overlap the rings; the tutorial panel fits under it.
- Onboarding and Settings remain scrollable.
- The completion overlay (emblem, Moves/Par/Best, Next Level, Replay, Level
  Select) fits inside its card with correct margins — no clipping or overlap.

No iPhone SE-class (compact, 4.7″) simulator is installed on this host; the 17e is
the smallest available iPhone. Available simulators: iPhone 17 Pro / 17 Pro Max /
17e / Air / 17.

### Manual VoiceOver check (rotation)

With VoiceOver on, open Level 1: the board element announces the rings remaining
and, after using the **"Rotate ring to opening"** custom action, that the held
ring is *aligned and ready to pull*. Confirm "Show Hint" and "Restart Level"
actions still work, and that the tutorial text is read aloud.

## Screenshots

`ScreenshotTour.test_capturePhase3Screens` and `test_capturePhase4Screens`
navigate each screen with the appropriate intro/bridge state and attach a
screenshot. The Phase 4A set is `docs/screenshots/phase-4a-*.png`
(rotation-tutorial, gap-unaligned, gap-aligned, level-complete). To regenerate:

```bash
xcodebuild -project ios/RingKnot/RingKnot.xcodeproj -scheme RingKnot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -configuration Debug test \
  -only-testing:RingKnotUITests/ScreenshotTour/test_capturePhase4Screens \
  -resultBundlePath /tmp/ss.xcresult
xcrun xcresulttool export attachments --path /tmp/ss.xcresult --output-path /tmp/ss_att
# then copy the phase-4a-* attachments (see manifest.json) into docs/screenshots/
```

`ScreenshotTour.test_capturePhase4bScreens` adds three Phase 4B stills:
`phase-4b-ready-state.png` (silver ring aligned + ready glow), `phase-4b-pull-release.png`
(board right after a **real** outward drag releases that ring — move counter at 1,
only the copper core left), and `phase-4b-copper-ready.png` (copper ring aligned +
ready glow).

**Screen recording.** `tools/capture_phase4b_demo.sh` drives
`ScreenshotTour.test_phase4bDemoWalkthrough` while `xcrun simctl io recordVideo`
captures the screen, to produce `docs/screenshots/phase-4b-rotation-demo.mov`. On
this machine the simulator's `recordVideo` failed intermittently with
`SimRenderServer.SimulatorError Code=2` (the headless render server drops its LCD
display between capture sessions), so the `.mov` was **not** produced here; the
three genuine stills above stand in as the required evidence. The script is kept
so the recording can be captured on a host where the render server is stable
(typically with the Simulator app fronted in an interactive GUI session).
