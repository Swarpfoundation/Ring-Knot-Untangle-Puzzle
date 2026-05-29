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

The eight exit directions match the JSON contract. `Direction.unitVector` provides a normalized `CGVector` so diagonals do not overshoot orthogonals during drag projection.

## Input projection

`touchesMoved` projects the touch delta onto the selected ring's exit unit vector. The ring slides only along that axis. A drag against the exit direction yields a small clamped negative offset that springs back. A drag past `0.65` cell units on release with no unmet prerequisites releases the ring; otherwise the ring snaps back with a shake.

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
