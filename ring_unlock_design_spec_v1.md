# Ring Unlock — Game Design Spec v1

## Product definition

This is a native mobile 2D puzzle game based on an interlocking open-ring mechanic. The player removes C-shaped rings one at a time by dragging them through their open gap direction. A ring only releases when its blocking rings have already been cleared. The level is complete when every silver blocker and every copper core piece has been removed.

The app must use original title, UI, ring meshes, sounds, and backgrounds. The reference screenshots define a mechanic and visual genre only; they are not production art.

## Core loop

1. Player scans the board.
2. Player selects one ring.
3. If the ring is currently unlocked and dragged in its exit direction, it slides out and disappears.
4. If the ring is locked or dragged in the wrong direction, it snaps back with a short shake and haptic tick.
5. Removed rings reveal the next legal moves.
6. Final copper knot pieces release last.
7. Win state triggers immediately after the last piece exits.

## Input and animation

- Supported directions: N, NE, E, SE, S, SW, W, NW.
- Drag motion is projected onto the selected ring’s exit vector.
- Release threshold: 0.65 cell units.
- Exit animation distance: 1.35 cell units past the board edge.
- Invalid snap-back duration: 0.18 seconds.
- Valid exit duration: 0.24 seconds for easy levels, 0.18 seconds for levels 10+.
- Haptics: light impact on valid release; warning tick on invalid move.
- Wrong direction should not rotate the ring; it should slide a little, then spring back.

## Coordinate and level notation

Cells use row letter + column number. `A1` is top-left. Row `A` is the top row. Levels 1–15 use a 5×5 board. Levels 16–20 use a 6×6 board. Suffixes `a`, `b`, and `c` represent overlapping visual offsets in the same cell for central knot pieces.

Piece notation: `S1@B3↑[S0]` means silver piece S1 is at cell B3, exits upward, and requires S0 to be removed first. Copper pieces use prefix `C`.

## Level pack

| Level | Name | Pieces | Difficulty | Pieces / dependencies | Canonical solution |
|---:|---|---:|---:|---|---|
| 1 | Single Hook | 2 | 1 | S1@B3↑; C1@C3→[S1] | S1↑, C1→ |
| 2 | Two Side Pins | 3 | 1 | S1@B2←; S2@B4→; C1@C3↓[S1,S2] | S1←, S2→, C1↓ |
| 3 | Top Cap | 4 | 1 | S1@A3↑; S2@B2←[S1]; S3@B4→[S1]; C1@C3↓[S2,S3] | S1↑, S2←, S3→, C1↓ |
| 4 | First Fork | 5 | 2 | S1@B3↑; S2@C2↙[S1]; S3@C4↘[S1]; S4@D3↓[S2,S3]; C1@C3→[S4] | S1↑, S2↙, S3↘, S4↓, C1→ |
| 5 | Bridge Latch | 6 | 2 | S1@A2↖; S2@A4↗; S3@B3↑[S1,S2]; S4@C2←[S3]; S5@C4→[S3]; C1@C3↓[S4,S5] | S1↖, S2↗, S3↑, S4←, S5→, C1↓ |
| 6 | Split Core | 7 | 2 | S1@B1←; S2@B5→; S3@A3↑[S1,S2]; S4@C2↙[S3]; S5@C4↘[S3]; C1@C3a←[S4,S5]; C2@C3b→[C1] | S1←, S2→, S3↑, S4↙, S5↘, C1←, C2→ |
| 7 | Lower Trap | 8 | 3 | S1@D2↙; S2@D4↘; S3@B2←; S4@B4→; S5@C3↑[S3,S4]; S6@D3↓[S1,S2,S5]; C1@C3a←[S6]; C2@C3b→[C1] | S3←, S4→, S5↑, S1↙, S2↘, S6↓, C1←, C2→ |
| 8 | Outer Arms | 8 | 3 | S1@A3↑; S2@B1←; S3@B5→; S4@C2↙[S1,S2]; S5@C4↘[S1,S3]; S6@D2←[S4]; S7@D4→[S5]; C1@C3↓[S6,S7] | S1↑, S2←, S3→, S4↙, S5↘, S6←, S7→, C1↓ |
| 9 | Bottom First | 9 | 3 | S1@E3↓; S2@D2↙[S1]; S3@D4↘[S1]; S4@B3↑; S5@C2←[S4,S2]; S6@C4→[S4,S3]; S7@B2↖[S5]; S8@B4↗[S6]; C1@C3↓[S7,S8] | S1↓, S2↙, S3↘, S4↑, S5←, S6→, S7↖, S8↗, C1↓ |
| 10 | Inner Clamp | 10 | 4 | S1@A2↖; S2@A4↗; S3@B3↑[S1,S2]; S4@B1←[S3]; S5@B5→[S3]; S6@C2↙[S4]; S7@C4↘[S5]; S8@D3↓[S6,S7]; C1@C3a←[S8]; C2@C3b→[C1] | S1↖, S2↗, S3↑, S4←, S5→, S6↙, S7↘, S8↓, C1←, C2→ |
| 11 | Four-Way Latch | 10 | 4 | S1@C1←; S2@C5→; S3@A3↑; S4@E3↓; S5@B2↖[S1,S3]; S6@B4↗[S2,S3]; S7@D2↙[S1,S4]; S8@D4↘[S2,S4]; C1@C3a←[S5,S7]; C2@C3b→[S6,S8,C1] | S3↑, S4↓, S1←, S2→, S5↖, S6↗, S7↙, S8↘, C1←, C2→ |
| 12 | Rim Gate | 11 | 4 | S1@A3↑; S2@B1←; S3@B5→; S4@E3↓; S5@D1↙[S4]; S6@D5↘[S4]; S7@B3↑[S1,S2,S3]; S8@C2←[S5,S7]; S9@C4→[S6,S7]; C1@C3a↓[S8,S9]; C2@C3b↑[C1] | S1↑, S2←, S3→, S4↓, S5↙, S6↘, S7↑, S8←, S9→, C1↓, C2↑ |
| 13 | Clockwise Spiral | 12 | 5 | S1@A1↖; S2@A3↑[S1]; S3@A5↗[S2]; S4@B5→[S3]; S5@D5↘[S4]; S6@E3↓[S5]; S7@E1↙[S6]; S8@D1←[S7]; S9@B1↖[S8]; S10@B3↑[S9]; C1@C3a←[S10]; C2@C3b→[C1] | S1↖, S2↑, S3↗, S4→, S5↘, S6↓, S7↙, S8←, S9↖, S10↑, C1←, C2→ |
| 14 | Double Key | 12 | 5 | S1@A2↖; S2@A4↗; S3@B2←[S1]; S4@B4→[S2]; S5@C1←[S3]; S6@C5→[S4]; S7@D2↙[S5]; S8@D4↘[S6]; S9@C2↑[S3,S7]; S10@C4↓[S4,S8]; C1@C3a←[S9]; C2@C3b→[S10,C1] | S1↖, S2↗, S3←, S4→, S5←, S6→, S7↙, S8↘, S9↑, S10↓, C1←, C2→ |
| 15 | Stacked Bridge | 13 | 5 | S1@A3↑; S2@B2↖[S1]; S3@B4↗[S1]; S4@C1←[S2]; S5@C5→[S3]; S6@D2↙[S4]; S7@D4↘[S5]; S8@E3↓[S6,S7]; S9@C2←[S2,S6]; S10@C4→[S3,S7]; C1@C3a↓[S8,S9,S10]; C2@C3b←[C1]; C3@C3c→[C2] | S1↑, S2↖, S3↗, S4←, S5→, S6↙, S7↘, S8↓, S9←, S10→, C1↓, C2←, C3→ |
| 16 | Outer Shell | 14 | 6 | S1@A2↖; S2@A5↗; S3@B1←[S1]; S4@B6→[S2]; S5@E1↙[S3]; S6@E6↘[S4]; S7@F3↓[S5]; S8@F4↓[S6]; S9@B3↑[S1,S3]; S10@B4↑[S2,S4]; S11@C2←[S9,S5]; S12@C5→[S10,S6]; C1@D3←[S7,S11]; C2@D4→[S8,S12,C1] | S1↖, S2↗, S3←, S4→, S5↙, S6↘, S7↓, S8↓, S9↑, S10↑, S11←, S12→, C1←, C2→ |
| 17 | Alternating Locks | 15 | 6 | S1@A3↑; S2@F3↓; S3@C1←; S4@C6→; S5@B2↖[S1,S3]; S6@B5↗[S1,S4]; S7@E2↙[S2,S3]; S8@E5↘[S2,S4]; S9@C2←[S5,S7]; S10@C5→[S6,S8]; S11@D3↓[S9]; S12@D4↓[S10]; C1@C3a↑[S11]; C2@C4a↑[S12]; C3@C3b→[C1,C2] | S1↑, S2↓, S3←, S4→, S5↖, S6↗, S7↙, S8↘, S9←, S10→, S11↓, S12↓, C1↑, C2↑, C3→ |
| 18 | Corkscrew | 16 | 7 | S1@A1↖; S2@A2↑[S1]; S3@A4↑[S2]; S4@A6↗[S3]; S5@B6→[S4]; S6@D6↘[S5]; S7@F5↓[S6]; S8@F3↓[S7]; S9@F1↙[S8]; S10@E1←[S9]; S11@C1←[S10]; S12@B2↖[S11]; S13@B3↑[S12]; S14@B4↑[S13]; C1@C3a←[S14]; C2@D4a→[C1] | S1↖, S2↑, S3↑, S4↗, S5→, S6↘, S7↓, S8↓, S9↙, S10←, S11←, S12↖, S13↑, S14↑, C1←, C2→ |
| 19 | Two-Phase Center | 17 | 7 | S1@A2↖; S2@A5↗; S3@B1←[S1]; S4@B6→[S2]; S5@F2↙; S6@F5↘; S7@E1←[S5]; S8@E6→[S6]; S9@B3↑[S1,S3]; S10@B4↑[S2,S4]; S11@E3↓[S5,S7]; S12@E4↓[S6,S8]; S13@C2←[S9,S11]; S14@C5→[S10,S12]; C1@D3←[S13]; C2@D4→[S14,C1]; C3@C3↑[C2] | S1↖, S2↗, S3←, S4→, S5↙, S6↘, S7←, S8→, S9↑, S10↑, S11↓, S12↓, S13←, S14→, C1←, C2→, C3↑ |
| 20 | Final Knot | 18 | 8 | S1@A4↑; S2@A2↑[S1]; S3@B1←[S2]; S4@B5→[S1]; S5@C1←[S3]; S6@C2←[S5]; S7@C4→[S4]; S8@C5→[S7]; S9@D2↙[S6]; S10@D4↘[S8]; S11@E2↓[S9]; S12@E4↓[S10]; S13@B3↑[S2,S4]; S14@C3→[S13,S6,S7]; S15@D3↓[S14,S11,S12]; C1@B3a←[S13,S14]; C2@C3a↑[C1,S15]; C3@C3b→[C2] | S1↑, S2↑, S4→, S3←, S7→, S8→, S5←, S6←, S13↑, S14→, S9↙, S10↘, S11↓, S12↓, S15↓, C1←, C2↑, C3→ |

## Native implementation target

iOS should be built with Swift and SpriteKit. Android should be built with Kotlin and a SurfaceView/Canvas render loop. Both apps should consume the same JSON level pack. The engine must remain deterministic; avoid a physics solver for v1 because physics introduces device-specific edge cases and makes level validation harder.

## Engine objects

`RingPiece` fields:
- `id`
- `kind`: silver or copper
- `cell`
- `exitDirection`
- `requires`
- `state`: locked, idle, dragging, exiting, cleared
- `zIndex`
- `visualOffset`

`LevelState` fields:
- `levelId`
- `clearedPieceIds`
- `currentSelection`
- `moveCount`
- `undoStack`
- `startedAt`
- `completedAt`

## Validation rules

Before shipping any level:
1. Every piece ID must be unique.
2. Every `requires` ID must exist.
3. The canonical solution must contain every piece exactly once.
4. The canonical solution must respect all dependencies.
5. Each solution drag must equal the piece exit direction.
6. No level should exceed 18 pieces on a phone screen for v1.
7. Every unlocked ring must be visually understandable: the player should be able to infer the exit direction from the gap.

## Red-team risks and corrections

Legal risk: do not copy the ad’s exact visual assets, account UI, brand, profile image, or background. Use original assets and title.

Gameplay risk: a dependency-only puzzle can feel scripted if the visual interlocks are not honest. The renderer must draw connectors and overlap layers that clearly justify why each ring is blocked.

Difficulty risk: hard levels can become unreadable on small screens. Use stronger outlines, tap-to-highlight, zoom-on-drag, and a hint system.

Engineering risk: iOS and Android can drift if levels are hardcoded twice. Store levels in shared JSON and run a golden replay validator on both platforms.

Monetization risk: aggressive ads early will destroy retention. Keep the first 10 levels uninterrupted; use rewarded hints later.
