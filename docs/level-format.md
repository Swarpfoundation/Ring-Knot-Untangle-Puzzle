# Level format

The shared level pack lives at `shared/levels/ring_unlock_level_pack_v1.json`. Both the iOS app and any future Android app read this file. The iOS build copies it into the app bundle at build time; the loader fails fast if it is missing or malformed.

## Top-level shape

```json
{
  "game": "Ring Unlock",
  "version": "1.0.0",
  "coordinateSystem": { ... },
  "mechanics": { ... },
  "levels": [ ... ]
}
```

`coordinateSystem` and `mechanics` are descriptive — the loader does not parse them. They document the contract that every level entry obeys.

## Level entry

```json
{
  "id": 3,
  "name": "Top Cap",
  "difficulty": 1,
  "board": { "rows": 5, "cols": 5 },
  "pieces": [
    { "id": "S1", "kind": "silver", "cell": "A3", "exitDirection": "N", "requires": [] },
    { "id": "S2", "kind": "silver", "cell": "B2", "exitDirection": "W", "requires": ["S1"] },
    { "id": "S3", "kind": "silver", "cell": "B4", "exitDirection": "E", "requires": ["S1"] },
    { "id": "C1", "kind": "copper", "cell": "C3", "exitDirection": "S", "requires": ["S2","S3"] }
  ],
  "solution": [
    { "id": "S1", "drag": "N" },
    { "id": "S2", "drag": "W" },
    { "id": "S3", "drag": "E" },
    { "id": "C1", "drag": "S" }
  ]
}
```

### Cells

Cells are written `<row letter><column number>` where `A` is the top row, `1` is the leftmost column. Suffixes `a`, `b`, and `c` denote rings stacked in the same cell (used for multi-ring copper cores). Boards may be 5×5 or 6×6.

### Directions

Eight cardinal directions: `N`, `NE`, `E`, `SE`, `S`, `SW`, `W`, `NW`. The renderer rotates the ring so its visible gap aligns with the exit direction.

### Ring kinds

- `silver` — blockers.
- `copper` — goal pieces. Every level must contain at least one copper ring.

### Dependencies

`requires` lists the IDs of rings that must be cleared first. The loader checks every dependency target exists and runs cycle detection. A cyclic dependency in the JSON will fail level pack loading at startup with `LevelLoaderError.dependencyCycle`.

### Solution path

`solution` lists the canonical removal order. Every entry's `drag` direction must equal the ring's `exitDirection`. The Swift test suite replays each solution path through the live engine to confirm the level is solvable.

## Validation summary

The loader rejects a pack that fails any of:

| Rule | Error |
| --- | --- |
| Duplicate level id | `duplicateLevelID` |
| Duplicate ring id within a level | `duplicateRingID` |
| `requires` references unknown ring | `unknownDependency` |
| `solution` references unknown ring | `unknownSolutionRing` |
| Unknown direction string | `unknownDirection` |
| Unknown cell coordinate | `unknownCell` |
| Level has zero copper rings | `missingCopper` |
| Dependency graph contains a cycle | `dependencyCycle` |
| Unknown ring kind | `unknownKind` |

## Derived fields

`zIndex` and `visualOffset` are not stored in JSON. They are derived deterministically by the iOS engine from the cell suffix (`""`, `"a"`, `"b"`, `"c"`) and the kind (copper sits above silver). Any platform that reads the pack must apply the same rule:

- base z = `100` for copper, `0` for silver
- z offset = sub-slot index (`0`, `1`, `2`, `3`)
- visual offset = small radial nudge per sub-slot for in-cell stacking

This keeps the JSON minimal and lets the renderer remain in charge of cosmetic decisions.
