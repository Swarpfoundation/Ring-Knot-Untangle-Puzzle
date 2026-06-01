# Anchor Rings & Blocker Clips (Phase 6A)

This document describes the geometry layer added in Phase 6A so the game looks
and plays like the reference art: a tight grid of mostly-closed silver rings
joined by small metal clamp bands, with a copper trefoil knot at the centre.

## 1. Ring body types

Every ring has a `bodyType` (`Ring.bodyType: RingBodyType`):

| bodyType       | shape                       | rotatable | removable (default) | role |
|----------------|-----------------------------|-----------|---------------------|------|
| `openRing`     | open C-ring with one gap    | yes       | `true`              | the pieces the player rolls + pulls out |
| `closedAnchor` | full closed ring, no gap    | no        | `false`             | fixed anchor/obstacle other rings interlock with |

Backward compatibility: a ring loaded without a `bodyType` defaults to
`openRing`, and a ring without an explicit `removable` flag derives it from the
body type (open → removable, anchor → fixed). Older packs load unchanged.

## 2. removable vs non-removable

`Ring.removable: Bool` decides whether a ring counts toward completion:

* A level is complete when **all removable rings** have left the board
  (`GameState.isComplete` → `level.removableRings.allSatisfy { cleared }`).
* Non-removable closed anchors are ignored by completion and **stay on the
  board** after the level is solved.
* The engine refuses to release a non-removable ring: `MoveValidator` returns
  `.notRemovable` (a calm "anchor" state, never an error). The move counter does
  not move and nothing is cleared.

## 3. Blocker clips

`BlockerClip` (see `Engine/Clip.swift`) is the small metal clamp drawn across a
ring tube:

| field            | meaning |
|------------------|---------|
| `id`             | unique within the level |
| `ownerRingId`    | the ring the clip is mounted on |
| `angleDegrees`   | position around the owner (screen convention: E=0, N=90, CCW+) |
| `material`       | `silver` / `copper` / `darkSteel` / `inherited` (use owner metal) |
| `kind`           | `blocker` (gates a dependency) / `connector` (decorative join) / `bridge` |
| `blocksRingIds`  | rings this clip visually holds |
| `visualWidthScale` | relative clamp width |
| `rotatesWithOwner` | open-ring clips roll with the ring; anchor clips stay put |

Clips are **procedural** — drawn by `RingTextureFactory.clipTexture(...)` as a
rounded-rectangle clamp with a brushed-metal gradient, rivet ridges and a dark
seam edge. No downloaded or copied art is used.

## 4. Interlocks

`Interlock` ties a dependency edge to the clip that explains it:

```
{ id, blockerRingId, blockedRingId, blockerClipId, contactAngleDegrees, description }
```

For every dependency `blockedRing.requires = [blockerRing]` the shipped pack
carries one interlock whose `(blockerRingId, blockedRingId)` matches the edge and
whose `blockerClipId` points at a real clip on the blocker. This is the contract
that keeps the dependency from being abstract.

## 5. Dependency visual rule

The replay validator fails a level if any `requires` edge has **no** matching
interlock/clip, unless the level sets `abstractOnly: true`. `abstractOnly` is an
escape hatch and is **not used** by any of the 20 shipped levels.

## 6. Rendering & z-depth

* `closedAnchor` rings bake their texture with a gap of `0°` → a full circle.
* `openRing` rings keep the 72° gap, rotated by `sprite.zRotation`.
* Clips live in one of two child layers on `RingNode`:
  * `rollingClipLayer` (open rings) — its `zRotation` tracks the ring's roll
    relative to its starting gap, so clips spin with the ring.
  * `staticClipLayer` (anchors) — fixed.
* `connector` clips sit slightly behind `blocker` clips (`zPosition` ±0.5) so
  overlapping bands between neighbouring rings read as interlocked, not flat.
* Reduce Motion: the anchor "tap" feedback and clip rolls fall back to static
  states; nothing pulses.
* Clamp bands are sized relative to the cell (`~0.22 × 0.15` of the ring
  diameter) so they stay legible on small iPhones.

## 7. Tutorial behaviour

* Onboarding now explains anchors ("Full closed rings are anchors — they don't
  move") and clips ("the small metal clips show where each ring is caught").
* The Level 1 tutorial's first prompt reads: *"The full ring is an anchor — it
  stays put. Rotate the open ring until its gap clears the clip."* The
  highlighted ring is always derived from the level's solution path
  (`nextSuggestedRingId`), never a hardcoded id, and the tutorial never
  auto-solves.

## 8. Replay validator rules (`tools/replay_validator.py`)

For all 20 levels the validator checks:

1. exactly 20 levels;
2. each level has at least the band minimum of closed anchors
   (1 for L1–10, 2 for L11–15, 3 for L16–20);
3. every closed anchor carries ≥1 clip;
4. clip `ownerRingId` and every `blocksRingIds` reference real rings; ids unique;
5. interlocks reference real rings and a real clip;
6. every dependency edge is covered by an interlock (unless `abstractOnly`);
7. the solution references only removable, non-anchor rings;
8. after replaying the solution, all removable rings are gone and **every anchor
   remains** on the board;
9. anchors are excluded from the "must start misaligned" rotation rule (they
   have no gap) and from the completion count.

## 9. Future Android parity

When the Android port is built it must mirror this model exactly: the same
`ring_unlock_level_pack_v1.json` is the single source of truth, including the
`bodyType` / `removable` fields and the `clips` / `interlocks` arrays. Android
should draw clips procedurally (Canvas/Compose) — never ship copied art — and
reproduce the rolling-vs-static clip behaviour and z-depth rules above.

## Phase 6B — interlock geometry & art polish

The clip/interlock model gained backward-compatible fields:

- `BlockerClip`: `depthRole` (over/under/bridge/connector), `contactRingId`,
  `contactPointMode` (ownerAngle/betweenCenters/explicit), `explicitPositionOffset`,
  `visualLayer` (foreground/midground/background), `clampStyle`
  (shortBand/wideBand/bridgeBand/rivetedBand), `blocksExitDirection`.
- `Interlock`: `visualContactMode` (clipBlocksGap/ringPassesUnderAnchor/
  ringHeldByBridge/decorativeConnector), `requiredGapClearanceAngleDegrees`,
  `contactDescription`.

Dependency blocker clips are now placed at the **contact rim between the two
rings** (`betweenCenters`) and read `over` the blocked ring. A dependency is only
considered "explained" by a **non-decorative** interlock — the replay validator
rejects a `requires` edge that has only a `decorativeConnector`. `abstractOnly` is
no longer permitted in the shipped pack. See `docs/art/interlock-visual-style.md`.
