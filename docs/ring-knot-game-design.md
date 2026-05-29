# Ring Knot — Game Design

## Pitch

Ring Knot is a tactile, deterministic puzzle. Each level shows a small grid of overlapping open C-shaped rings. The player removes rings one at a time by dragging each through the gap in its own ring. A ring only releases when every ring threaded through it has already been cleared. The level is over when the board is empty.

The visual genre — interlocking metallic rings on a dark surface — is inspired by a common puzzle archetype. All in-app art, branding, UI, audio, and copy in this project are original.

## Core loop

1. The player scans the board for an unblocked ring.
2. Selecting a ring lights up its selection ring.
3. Dragging in the ring's exit direction projects motion onto that direction.
4. Releasing past the threshold removes the ring with a success haptic.
5. Releasing too short, or dragging the wrong direction, snaps the ring back with a warning haptic.
6. The remaining rings are revealed as their blockers leave.
7. The level completes when the last copper core ring exits.

## Rings

- **Silver** rings are blockers. They surround the copper core and lock each other in.
- **Copper** rings are the goal pieces. The level cannot complete until every copper ring exits.

The player infers the exit direction from the visible gap. The renderer rotates each ring so the gap points in the exit direction.

## Difficulty curve

- Levels 1–3 introduce single dependencies on a 5×5 board.
- Levels 4–9 layer diagonals and forks.
- Levels 10–15 stack overlapping copper cores in the same cell.
- Levels 16–20 widen the board to 6×6 and add longer dependency chains.

## Player feedback

- **Visual**: selection glow, hint pulse, exit slide with fade, snap-back shake, drop shadow under each ring.
- **Haptic**: light tap on select, success notification on valid release, warning notification on invalid drag, success notification on level complete.
- **Audio**: not in this milestone. Hooks are kept out of the engine; future audio can subscribe to the same `GameSceneDelegate` events as haptics.

## Out of scope for milestone 1

- No accounts, leaderboards, network requests, ads, IAP, or analytics.
- No physics solver. Movement is animated with deterministic actions so a solution path is always replayable.
- No Android implementation yet. Shared JSON is the source of truth for the next platform.

## Validation philosophy

The shared level pack is the single source of truth. The Swift loader rejects malformed data on startup rather than silently dropping pieces. Every shipped level is verified during tests by replaying its `solution` path and confirming the board ends empty.
