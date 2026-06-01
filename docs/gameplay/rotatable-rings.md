# Rotatable rings (Phase 4A)

The core action is **rotate, then pull**. Every ring is an open metal circle with
a single gap. A ring cannot be removed until:

1. its dependency blockers are cleared,
2. its gap is rolled into alignment with its exit direction, and
3. the player pulls it out through that gap.

This document is the contract for the mechanic across platforms.

## Why rings rotate

A flat "drag toward the exit" verb is shallow. Making the gap a thing the player
physically aligns turns each ring into a small spatial puzzle: read where the gap
is, roll it to the opening, then pull. It also reads as a real object — an open
ring you twist in your fingers — which suits the tactile, deterministic tone.

## How gap alignment works

Angles use a screen convention: **East = 0°, North = 90°, West = 180°,
South = 270°, counter-clockwise positive**, normalized to `[0, 360)`.

- `targetAngle` — the angle the gap must reach. It is the ring's `exitDirection`
  mapped to that convention (`Direction.exitAngleDegrees`).
- `gapAngle` — the gap's current angle. It starts at the ring's `initialGapAngle`
  (from the shared JSON), deliberately offset from the target.
- `tolerance` — `alignmentToleranceDegrees` for the level. A ring is **aligned**
  when `|shortestAngularDistance(gapAngle, targetAngle)| <= tolerance`.

All comparisons go through a shortest-signed-distance helper, so a gap can be
rolled through any number of full turns without numerical drift changing the
alignment verdict (`RingRotation` in the engine; `RingRotationTests` covers it).

## Gesture model

One finger does everything:

- **Touch down** on a ring selects it.
- **Tangential motion** (dragging *around* the ring centre) rolls the gap: the
  gap angle changes by the angular delta of the finger about the ring's home
  centre. Radial motion barely changes that angle, so pulling does not spin.
- **Magnetic snap**: when the gap comes within ~7° of the exit it snaps exactly
  onto it, with a light haptic and a "ready" glow. It never snaps from far away.
- **Pull to release**: once aligned, pulling outward along the exit — a clear
  projection past threshold *and* genuine outward travel from the centre —
  removes the ring. Requiring outward radial travel means a tangential roll can
  never release a ring by accident; when ambiguous, rotation wins.
- **Pull before aligning** is refused with a "rotate first" nudge.
- **Pull while still blocked** is refused with the existing blocked feedback.

### Final tuned values (Phase 4B)

All distances scale by cell size; angles are degrees. Tuned on the iPhone 17 Pro
and iPhone SE (3rd gen) simulators.

| Knob | Value | Why |
| --- | --- | --- |
| Rotation begin radius | 0.10 cell | Track rotation once the finger leaves the hub; avoids wild angle jumps near centre. |
| Release projection (along exit) | 0.50 cell | Deliberate outward pull, not a twitch. |
| Release radial travel (from centre) | 0.16 cell | The anti-accident guard — a tangential roll keeps constant radius, so it never reaches this. |
| Snap window | 6° | Subtle magnetic assist onto the exit, never a yank. |
| Alignment tolerance | 22° → 18° → 15° → 12° | Forgiving early, gently tighter later (by level band). |
| Pull-slide clamp | 0.42 cell | The ring visibly eases out "about to come free" before it pops. |
| Release animation | 0.24 s (0.12 s Reduce Motion) | Snappy exit; shorter when motion is reduced. |
| Snap spin animation | 0.12 s (instant in Reduce Motion) | Quick settle onto the exit. |

These mirror the descriptive `mechanics` fields in the shared JSON
(`releaseThresholdCellUnits`, `radialPullThresholdCellUnits`,
`ringDefaults.rotationBeginRadiusCellUnits`, `ringDefaults.snapDegrees`) so a
future port reads the same numbers. The alignment transition fires exactly one
light haptic; the snap itself adds no second tick. Copper rings use the identical
`RingNode` path, so they roll and release exactly like silver.

## Alignment tolerance

Tolerance widens early and tightens later so rotation stays forgiving while the
real difficulty comes from longer dependency chains, not punishing windows:

| Levels | Tolerance |
| --- | --- |
| 1–5 | 22° |
| 6–10 | 18° |
| 11–15 | 15° |
| 16–20 | 12° |

The value is stored per level as `alignmentToleranceDegrees`; the bands above are
the default if a level omits it.

## Release rules (engine truth)

`MoveValidator.evaluateRelease(ringId:gapAngleDegrees:clearedIds:)` returns, in
priority order: `.unknownRing`, `.alreadyCleared`, `.blockedByPrerequisite`,
`.notAligned`, `.accepted`. Prerequisites are checked before alignment, so an
aligned-but-blocked ring reports the blocker (you cannot remove it regardless),
while an unblocked ring with a misaligned gap reports `.notAligned`.

`GameState.attemptRelease` increments the move counter **only** on `.accepted` —
rolling the gap, or a refused pull, is never a move.

## Tutorial behavior

Level 1 teaches the verb in three beats, all driven by the level's `solution`
path (no hard-coded ids), never auto-solving and never blocking input:

1. *"Rotate the ring until the opening faces the arrow."* — the first solution
   ring is highlighted with a curved rotation cue.
2. *"Now pull it out through the gap."* — shown the moment that ring aligns.
3. *"Some rings are blocked. Clear them first, then free the copper knot."* —
   after the first release.

The onboarding carousel mirrors this: rotate to find the opening → line the gap
up with the exit → pull it free, clearing blockers before the copper knot.

## How future Android must match iOS

The shared JSON is the source of truth. Android must:

- read `initialGapAngle` (degrees, same screen convention) and
  `alignmentToleranceDegrees` per level from
  `shared/levels/ring_unlock_level_pack_v1.json`;
- map `exitDirection` to the same `targetAngle` (E=0, N=90, CCW+);
- use the same shortest-angular-distance alignment test and the same
  prerequisite-before-alignment release priority;
- start every ring misaligned and only release on rotate-then-pull.

Porting `RingRotation` and `MoveValidator.evaluateRelease` verbatim, plus reading
the two JSON fields, yields identical behavior. The Python `replay_validator.py`
is the cross-platform oracle.

## QA checklist

- [ ] Level 1 starts with the gap visibly off; a short roll aligns it.
- [ ] The ring snaps + glows + ticks when aligned.
- [ ] Pulling before aligning does not remove the ring ("rotate first").
- [ ] Pulling an aligned, unblocked ring removes it and counts one move.
- [ ] Rolling the gap alone never changes the move counter.
- [ ] An aligned-but-blocked ring shows the blocked feedback, not release.
- [ ] Copper rings require alignment too.
- [ ] Reduce Motion: static highlight, no pulsing/particles, instant snap.
- [ ] VoiceOver: board summary states remaining rings and, when a ring is held,
      whether it is aligned; the "Rotate ring to opening" action works.
- [ ] `python3 tools/replay_validator.py` passes for all 20 levels.

## Interaction with anchors (Phase 6A)

- Closed anchor rings have **no gap** and are never rolled or released; tapping
  one gives a calm steel pulse, not an error, and never counts as a move.
- Open rings still rotate-then-pull exactly as above. Their blocker clips roll
  with them; anchor clips stay put.
- [ ] Tapping an anchor leaves the move counter unchanged.
- [ ] Each level shows at least one full closed anchor with a clamp band.
- See `docs/gameplay/anchor-blocker-system.md` for the full model.

## Blocked feedback (Phase 6B)

- Pulling a ring before its gap clears the clip is refused; the accessibility
  summary says to rotate the gap clear of the clip.
- Pulling an aligned but still-blocked ring flashes the blocker ring(s) and their
  clamps amber, pointing at what to clear first (`flashBlockers`).

## Phase 6C contact bands

Contact clamps are now fixed at the true contact point between two rings (the ring's
gap rotates past the fixed clamp, rather than the clamp rolling with the ring).
Blocked pulls flash both the blocker ring and the exact contact band/bridge holding
the selected ring.
