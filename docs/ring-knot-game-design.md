# Ring Knot — Game Design

## Pitch

Ring Knot is a tactile, deterministic puzzle. Each level shows a small grid of overlapping open C-shaped rings. Each ring is a physical open circle with one gap: the player **rolls** a ring to line its gap up with the way out, then **pulls** it free through that gap. A ring only releases when every ring threaded through it has already been cleared. The level is over when the board is empty.

The visual genre — interlocking metallic rings on a dark surface — is inspired by a common puzzle archetype. All in-app art, branding, UI, audio, and copy in this project are original.

## Core loop

1. The player scans the board for an unblocked ring.
2. Selecting a ring lights up its selection ring.
3. Dragging *around* the ring rolls it; the player aligns the gap with the exit
   direction. A subtle snap, "ready" glow, and light haptic confirm alignment.
4. Pulling the aligned ring outward along the exit removes it with a success haptic.
5. Pulling before aligning is refused ("rotate first"); pulling a still-blocked
   ring shows the blocked feedback. Both snap back with a warning haptic.
6. The remaining rings are revealed as their blockers leave.
7. The level completes when the last copper core ring exits.

See `docs/gameplay/rotatable-rings.md` for the full rotation mechanic, thresholds,
and the cross-platform contract.

## Rings

- **Silver** rings are blockers. They surround the copper core and lock each other in.
- **Copper** rings are the goal pieces. The level cannot complete until every copper ring exits. Copper rings rotate and must be aligned before release, exactly like silver.

Each ring starts with its gap deliberately misaligned (`initialGapAngle` in the shared JSON). The player reads where the gap is and rolls it to the exit before pulling.

## Difficulty curve

- Levels 1–3 introduce single dependencies on a 5×5 board.
- Levels 4–9 layer diagonals and forks.
- Levels 10–15 stack overlapping copper cores in the same cell.
- Levels 16–20 widen the board to 6×6 and add longer dependency chains.

## Player feedback

- **Visual**: selection glow, a curved "roll me" rotation cue, a bright "ready"
  ring when the gap aligns, hint pulse, exit slide with fade, snap-back shake,
  drop shadow under each ring.
- **Haptic**: light tap on select, a lighter tick when the gap snaps into
  alignment, success on valid release, warning on a refused pull, success on
  level complete.
- **Audio**: button/select/release/invalid/complete SFX. Alignment is haptic-only
  (no continuous rotation sound) to avoid fatigue.

Alignment tolerance widens early and tightens later (22° → 12°) so rotation stays
readable; difficulty comes from longer dependency chains, not tight windows.

## Out of scope for milestone 1

- No accounts, leaderboards, network requests, ads, IAP, or analytics.
- No physics solver. Movement is animated with deterministic actions so a solution path is always replayable.
- No Android implementation yet. Shared JSON is the source of truth for the next platform.

## Validation philosophy

The shared level pack is the single source of truth. The Swift loader rejects malformed data on startup rather than silently dropping pieces. Every shipped level is verified during tests by replaying its `solution` path and confirming the board ends empty.
