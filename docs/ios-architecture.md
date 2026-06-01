# iOS architecture

## Layers

```
SwiftUI (RingKnotApp → RootView → HomeView / LevelSelectView / GameView)
        │
        ├── AppEnvironment   ─ owns LevelPack + ProgressSnapshot
        ├── GameController   ─ bridges SwiftUI ↔ SpriteKit, owns the scene
        │
SpriteKit (GameScene + RingNode)
        │
        ├── RingTextureFactory   ─ CoreGraphics-drawn silver/copper material
        │
Pure Swift engine
        ├── Direction, Cell, Board
        ├── Ring, Level, LevelPack
        ├── LevelLoader (JSON parse + validation)
        ├── MoveValidator
        ├── GameState
        └── ProgressStore (UserDefaults)
```

The pure Swift engine has no UIKit, no SwiftUI, no SpriteKit imports. It is the layer the tests exercise directly. The rendering and UI layers depend on the engine; the engine depends on nothing but `Foundation`.

## Module choices

- **SwiftUI shell**: navigation, HUD, level select grid, completion overlay. `NavigationStack` with a typed `HomeRoute` enum so deep links and back behaviour are predictable.
- **SpriteKit gameplay**: the gameplay scene is rebuilt from immutable level data whenever the view resizes or the level changes. Rings are `SKSpriteNode`s textured from a `CoreGraphics`-rendered `UIImage` so the visual is deterministic and no bitmap assets are required.
- **CoreGraphics for rings**: each ring texture is a stroked arc with a gradient + dashed highlight + drop shadow. Silver and copper share the same drawing routine with a different palette. This avoids any third-party art and keeps the build hermetic.

## Coordinate system

Cell `A1` is the top-left of the board. Rows increase downward. The SpriteKit scene flips this when it positions nodes because SpriteKit's y-axis points up. The conversion happens in `GameScene.pointForCell(_:)`.

The eight exit directions match the JSON contract. `Direction.unitVector` is the raw JSON vector; **`Direction.sceneUnitVector` / `sceneRadians`** are the scene-space (SpriteKit y-up) versions used by all rendering, drag, and gap-alignment maths so "North" reads as up. `Direction.exitAngleDegrees` gives the target gap angle (E=0°, N=90°, CCW+).

## Input model (Phase 4A — rotate then pull)

`touchesMoved` does two things on the selected ring. **Rotation:** the gap angle
changes by the angular delta of the finger about the ring's home centre, so
dragging *around* the ring rolls it while radial motion barely turns it. A gap
within ~7° of the exit snaps onto it with a light haptic and a "ready" glow.
**Pull:** only an aligned ring slides outward along its exit. On release, a pull is
recognised when the exit-projected travel passes threshold **and** the finger has
moved genuinely outward from the centre — so a tangential roll never releases a
ring by accident. An aligned, unblocked pull removes the ring; a pull before
aligning ("rotate first") or while blocked snaps back with a warning. Rolling the
gap is never a move; only an accepted release counts. See
`docs/gameplay/rotatable-rings.md`.

## Persistence

`ProgressStore` writes a typed Codable snapshot into `UserDefaults` under a versioned key. The snapshot contains the highest unlocked level and per-level records (`completed` flag and `bestMoveCount`). Tests construct an isolated `UserDefaults` suite so they never touch the real app domain.

## Accessibility

- VoiceOver labels are attached to navigation buttons, level cards, the hint button, restart button, and the game board. Level cards announce difficulty state and best-move record when present.
- The level select uses an adaptive grid so it scales with Dynamic Type.
- `accessibilityReduceMotion` is read from `@Environment` and threaded into `GameScene`. When enabled, the scene skips the shake on snap-back and shortens exit and hint animations.

## Haptics

A single `Haptics` singleton owns prepared `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` instances. Devices without haptic hardware fall through with no-ops because UIKit's generators ignore calls when the device cannot fire them.

## Testing strategy

`RingKnotTests` is a unit-test target that links `@testable import RingKnot`. The shipped level pack is added as a resource on both the app and the test target so test code can load it via `Bundle(for: BundleAnchor.self)`. The test suite covers every requirement:

1. JSON loading from the shipped pack.
2. All loader validation errors.
3. Direction and cell parsing including suffixes.
4. Dependency unlock logic.
5. Invalid move rejection.
6. Valid move acceptance.
7. Level completion via the canonical solution.
8. Persistence encode/decode round-trip.
9. All 20 shipped levels are solvable by replaying their `solution` path.
10. Blocked rings cannot be removed before prerequisites are cleared.

## Build

The project is generated with XcodeGen from `ios/RingKnot/project.yml`. The level pack is consumed from `shared/levels/ring_unlock_level_pack_v1.json` via a relative resource reference. No third-party Swift packages are linked.

## Phase 3 — onboarding & ship-readiness

### Preferences (typed settings store)

`Preferences` (`@MainActor ObservableObject`) is the single source of truth for
user-facing settings and first-session flags. Every persisted key is namespaced
under `com.swarpfoundation.ringknot.pref.*` and declared in one private `Key`
enum — no raw `UserDefaults` strings are scattered through the UI. The four
values are `soundEnabled`, `hapticsEnabled`, `onboardingCompleted`, and
`level1TutorialCompleted`. Settings default **on**; first-session flags default
**false**. `didSet` observers push the audio/haptics toggles straight into the
`AudioManager` / `Haptics` singletons, so a change takes effect immediately.

`AppEnvironment` owns a `Preferences` instance and injects it into the
environment alongside itself. Under `DEBUG`, launch arguments
(`-uiTestSkipIntro`, `-uiTestResetIntros`, `-uiTestResetTutorial`,
`-uiTestSoundOff`) drive deterministic intro state for UI tests.

### Onboarding

`OnboardingView` is a three-page `TabView` shown once on first launch via a
`fullScreenCover` in `RootView`, and re-armable from Settings. Pages are
game-specific (escape through the gap, clear blockers first, hint/restart/moves)
and use the generated brand art with SF Symbol fallbacks. It honours Dynamic
Type (each page scrolls) and Reduce Motion (paging animation disabled).

### Level 1 tutorial

The tutorial highlights the **first ring of the level's `solution` path** — never
a hard-coded ring id; the suggestion comes from `MoveValidator.nextSuggestedRingId`.
`GameScene` draws a persistent glow on that ring plus a directional arrow
(`ui_drag_arrow_master`) rotated to the ring's exit direction. After the first
successful move the panel switches to "Clear blockers first…"; it completes after
the second move (or level completion) and never blocks input or auto-solves.
Reduce Motion makes the highlight static.

### Progression & completion

`AppEnvironment` exposes `isUnlocked`, `isCompleted`, `continueTargetID` (the
highest unlocked-but-incomplete level, surfaced as Home's **Continue** button)
and `hasProgress`. Level cards render number, difficulty label
(`Level.difficultyLabel`), par (`Level.parMoveCount` = solution length), best, and
a distinct completed state; locked levels stay visible but disabled.
`CompletionInfo` carries moves/par/best/`isNewBest`/`isLastLevel`; the completion
overlay shows "New Best!" when applicable and replaces Next with "All Levels
Complete" on level 20. **Play behaviour is deterministic:** Home's primary action
always opens Level Select; resuming is an explicit Continue button — so the Play
button never depends on hidden state.

### Haptics & audio

`Haptics` is `@MainActor`, gated on both the user setting and
`CHHapticEngine.capabilitiesForHardware().supportsHaptics`, and degrades silently
on unsupported hardware. Events: selection on select, warning on invalid, success
on release, a stronger success (notification + heavy impact) on completion, and a
light tap on UI buttons. `AudioManager` is an in-memory-gated `AVAudioPlayer`
pool; turning Sound off mutes all SFX immediately. There is no music or looping.

### Privacy

`PrivacyInfo.xcprivacy` ships in the app bundle (declared `false` tracking, empty
tracking domains, no collected data, `UserDefaults` required-reason `CA92.1`).
See `docs/privacy.md` for the full audit.

## Phase 4A — rotatable ring release

The pure engine gains a rotation layer that the renderer drives:

- **`RingRotation`** (engine) — gap/target/tolerance with stable angle maths
  (normalize, shortest signed distance, alignment, snap). Multiple whole turns
  never change the alignment verdict. Free functions are reused by the validator.
- **`Ring.initialGapAngleDegrees`** and **`Level.alignmentToleranceDegrees`** load
  from the shared JSON (`LevelLoader`), with deterministic fallbacks. `Level.rotation(for:)`
  builds a ring's starting `RingRotation`.
- **`MoveValidator.evaluateRelease(ringId:gapAngleDegrees:clearedIds:)`** returns
  `.notAligned` when the gap is off (prerequisites are checked first), and
  `GameState.attemptRelease` only counts a move on `.accepted`.
- **`RingNode`** bakes its texture with the gap at screen-east and drives the
  visible gap with `sprite.zRotation` (so rotation is a cheap node transform, not a
  per-frame redraw). It owns its live `RingRotation`, the snap, and the "ready"
  glow. **`GameScene`** implements the rotate/pull gesture, a procedural curved
  rotation cue for the tutorial, and `gameSceneDidAlignSuggestedRing` /
  `gameSceneDidUpdateSelection` callbacks. The DEBUG test bridge adds
  rotate-to-aligned / rotate-to-misaligned / try-release / rotate-then-pull hooks.
- **Accessibility**: the board summary names the held ring's alignment, and a
  "Rotate ring to opening" custom action aligns the next solvable ring without a
  gesture.

## Anchors & blocker clips (Phase 6A)

- **Engine**: `Ring.bodyType` (`openRing`/`closedAnchor`) + `Ring.removable`;
  `BlockerClip` / `Interlock` model types (`Engine/Clip.swift`);
  `Level.clips` / `Level.interlocks` / `Level.abstractOnly`. `GameState.isComplete`
  counts only removable rings. `MoveValidator` returns `.notRemovable` for anchors
  and skips them in hints. `LevelLoader` parses + referentially validates the new
  fields.
- **Render**: `RingNode` bakes anchors as full circles, draws clip child nodes in
  a rolling layer (open rings) or static layer (anchors), and shows a calm anchor
  pulse on tap. `RingTextureFactory.clipTexture(...)` draws clamp bands
  procedurally. `GameScene` treats anchor taps as non-moves.
- **DEBUG**: `-uiTestUnlockAll` unlocks every level for screenshot tours (gated
  out of Release). See `docs/gameplay/anchor-blocker-system.md`.

## Phase 6B — interlock geometry & art

- **Model**: `Engine/Clip.swift` gains `ClipDepthRole`, `ClipContactPointMode`,
  `ClipVisualLayer`, `ClampStyle`, `ClipOffset`, and `InterlockVisualContactMode`
  with `explainsDependency`. All fields backward compatible.
- **Render**: `RingTextureFactory.clipTexture` adds bevel + per-style rivets;
  `RingNode.buildClips` places clamps by `contactPointMode`, layers by
  `depthRole`, and adds a contact shadow; anchors get a drop shadow and copper a
  warm sheen. `GameScene` sets `ignoresSiblingOrder` and `flashBlockers(...)`.
- **DEBUG**: `bridge.tryReleaseBlocked` triggers a genuine blocked-feedback flash
  for the screenshot tour (excluded from Release). See
  `docs/art/interlock-visual-style.md`.

## Phase 6C — tube occlusion

- **Render**: `GameScene.buildContactBands()` draws scene-level bands between owner
  and contact ring centres with depthRole→z occlusion and contact shadows;
  `retireBands(forRing:)` fades them on exit; `flashBands(blocking:)` highlights the
  exact clamp on a blocked pull. Per-ring render z is `zIndex·1000 + order·4`.
  `RingNode` now renders only legacy rolling clips (`!clip.isContactBand`).
- **Model**: `BlockerClip.isContactBand` classifies scene-level vs rolling clips.
- **Background**: `addBoardMotif(...)` adds a faint original graphite motif (abstract
  arcs + non-readable strokes, alpha 0.05) — no copied reference content.

## Phase 6D — split-tube occlusion

- **Model**: `Engine/CrossingZone.swift` — `OcclusionRole`, `CrossingZone`, and the
  pure `Level.crossingZones()` / `tubeCoverageDegrees(for:)` helpers.
- **Render**: `GameScene.makeTubeOverArc(...)` draws short tube over-arcs above the
  contact bands at `tubeOverClip` crossings (built once, in the band's container so
  they retire together). `retireBands(forRing:)` now fades + scales + slides.
  `RingNode.settlePop()` adds the alignment pop; `pulseAsBlocker` pulses once.
