#!/usr/bin/env python3
"""Add rotatable-ring fields to the shared level pack, in place and idempotently.

Phase 4A makes every ring an open circle whose gap must be rolled to face its
exit direction before it can be pulled out. For iOS and any future Android build
to behave identically, the *initial* gap angle and the per-level alignment
tolerance live in the shared JSON (the source of truth) rather than being derived
per platform.

This script writes:

  * `mechanics.rotationModel` — a short prose description of the mechanic.
  * `mechanics.ringDefaults.alignmentToleranceDegreesByBand` — the tolerance curve.
  * `level.alignmentToleranceDegrees` — explicit per-level tolerance.
  * `piece.initialGapAngle` — explicit per-ring starting gap angle (degrees,
    screen convention: E=0, N=90, CCW positive), deliberately offset from the
    exit direction so the ring starts misaligned but solvable.

It does NOT touch ids, dependencies, cells, exit directions, board sizes, or the
solution order. Re-running it reproduces the same numbers (deterministic).

Run:  python3 tools/apply_rotation_fields.py
"""

import json
import os
from collections import OrderedDict

PACK = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "shared", "levels", "ring_unlock_level_pack_v1.json",
)

# Gap angle (screen convention, CCW from East) at which a gap faces each exit.
EXIT_ANGLE = {
    "E": 0, "NE": 45, "N": 90, "NW": 135,
    "W": 180, "SW": 225, "S": 270, "SE": 315,
}

# Deterministic offsets applied per ring index within a level. Each magnitude is
# comfortably larger than any tolerance band (max 22°), so no ring starts aligned,
# yet small enough that aligning is a short, readable roll rather than a chore.
OFFSETS = [60, -75, 90, -55, 70, -100, 50, -85, 110, -65,
           80, -50, 95, -70, 105, -60, 85, -95]


def tolerance_for(level_id):
    if level_id < 6:
        return 22
    if level_id < 11:
        return 18
    if level_id < 16:
        return 15
    return 12


def normalize(deg):
    return deg % 360


def reorder_level(level, tolerance):
    """Return an OrderedDict with alignmentToleranceDegrees just after difficulty."""
    out = OrderedDict()
    for key, value in level.items():
        if key == "alignmentToleranceDegrees":
            continue  # drop any stale copy; re-inserted below
        out[key] = value
        if key == "difficulty":
            out["alignmentToleranceDegrees"] = tolerance
    if "alignmentToleranceDegrees" not in out:
        out["alignmentToleranceDegrees"] = tolerance
    return out


def main():
    with open(PACK, "r", encoding="utf-8") as handle:
        data = json.load(handle, object_pairs_hook=OrderedDict)

    mechanics = data.setdefault("mechanics", OrderedDict())
    mechanics["rotationModel"] = (
        "Each ring is an open circle with one gap. The player rolls the selected "
        "ring (dragging tangentially around its centre) until the gap is within "
        "alignmentToleranceDegrees of its exitDirection, then pulls it out through "
        "the gap along that direction. A ring never releases while its gap is "
        "misaligned or while any requires dependency is still on the board."
    )
    ring_defaults = mechanics.setdefault("ringDefaults", OrderedDict())
    ring_defaults["alignmentToleranceDegreesByBand"] = OrderedDict([
        ("levels1to5", 22), ("levels6to10", 18),
        ("levels11to15", 15), ("levels16to20", 12),
    ])
    ring_defaults["initialGapAngleField"] = (
        "initialGapAngle: gap angle in degrees (E=0, N=90, CCW+) the ring starts "
        "at; offset from exitDirection so the player must rotate to align."
    )

    new_levels = []
    for level in data.get("levels", []):
        level_id = level.get("id")
        tol = tolerance_for(level_id)
        for index, piece in enumerate(level.get("pieces", [])):
            exit_dir = piece.get("exitDirection")
            target = EXIT_ANGLE[exit_dir]
            offset = OFFSETS[index % len(OFFSETS)]
            piece["initialGapAngle"] = int(normalize(target + offset))
        new_levels.append(reorder_level(level, tol))
    data["levels"] = new_levels

    with open(PACK, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")

    print(f"Updated {len(new_levels)} levels with rotation fields -> {PACK}")


if __name__ == "__main__":
    main()
