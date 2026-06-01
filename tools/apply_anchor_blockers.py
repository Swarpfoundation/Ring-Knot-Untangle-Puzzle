#!/usr/bin/env python3
"""Add closed-anchor rings, blocker clips, and interlocks to the level pack.

Phase 6A geometry correction. The original game (see docs/screenshots reference
art) is a tight grid of mostly-closed silver rings joined by little metal clamp
bands, with a copper trefoil knot at the centre. This script upgrades the 20
shipped levels to match that look *without* changing any existing ring, cell,
dependency, or solution path:

  * It ADDS `closedAnchor` rings (full closed rings, non-removable) into empty
    cells embedded in each level's cluster, following a complexity curve:
        levels  1-5  -> 1 anchor
        levels  6-10 -> 1-2 anchors
        levels 11-15 -> 2-3 anchors
        levels 16-20 -> 3-4 anchors
  * It ADDS one blocker clip + one interlock per `requires` edge, so every
    dependency is visually explained by a clamp on the blocking ring.
  * It ADDS at least one connector clip to every anchor, pointing at its nearest
    neighbour, so anchors read as physically clamped into the grid.

Existing open rings are left untouched (no bodyType field) and therefore default
to openRing / removable=true in both the Swift loader and the replay validator.

Re-running is reproducible: anchors/clips/interlocks are rebuilt from scratch
each run. Standard library only.

Run:  python3 tools/apply_anchor_blockers.py
"""

import json
import math
import os

PACK = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "shared", "levels", "ring_unlock_level_pack_v1.json",
)

# How many anchors each level should carry (must be satisfiable by empty cells).
def anchor_target(level_id):
    if level_id <= 5:
        return 1
    if level_id <= 8:
        return 1
    if level_id <= 10:
        return 2
    if level_id <= 13:
        return 2
    if level_id <= 15:
        return 3
    if level_id <= 18:
        return 3
    return 4


def parse_cell(raw):
    """Return (row, col) ignoring the a/b/c sub-slot suffix."""
    row = ord(raw[0].upper()) - 65
    digits = ""
    for ch in raw[1:]:
        if ch.isdigit():
            digits += ch
        else:
            break
    return row, int(digits) - 1


def cell_name(row, col):
    return f"{chr(65 + row)}{col + 1}"


# Gap angle (screen convention, CCW from East) that faces each exit direction.
EXIT_ANGLE = {
    "E": 0.0, "NE": 45.0, "N": 90.0, "NW": 135.0,
    "W": 180.0, "SW": 225.0, "S": 270.0, "SE": 315.0,
}


def scene_angle(from_rc, to_rc):
    """Scene-convention angle (E=0, N=90, CCW+, y-up) from one cell to another."""
    dr = to_rc[0] - from_rc[0]      # row increases downward
    dc = to_rc[1] - from_rc[1]
    ang = math.degrees(math.atan2(-dr, dc))
    return round((ang + 360.0) % 360.0, 1)


def angular_distance(a, b):
    """Smallest absolute difference between two angles (degrees)."""
    d = abs((a - b) % 360.0)
    return min(d, 360.0 - d)


def occupied_base_cells(pieces):
    return {parse_cell(p["cell"]) for p in pieces}


def neighbors(rc):
    r, c = rc
    return [(r + dr, c + dc)
            for dr in (-1, 0, 1) for dc in (-1, 0, 1)
            if not (dr == 0 and dc == 0)]


def choose_anchor_cells(level, count):
    rows = level["board"]["rows"]
    cols = level["board"]["cols"]
    occupied = occupied_base_cells(level["pieces"])
    empties = [(r, c) for r in range(rows) for c in range(cols)
               if (r, c) not in occupied]

    chosen = []
    for _ in range(count):
        if not empties:
            break
        # Prefer the empty cell most embedded in the cluster: most occupied
        # (rings + already-chosen anchors) neighbours, then reading order.
        filled = occupied | set(chosen)
        def score(rc):
            return sum(1 for n in neighbors(rc) if n in filled)
        empties.sort(key=lambda rc: (-score(rc), rc[0], rc[1]))
        pick = empties.pop(0)
        chosen.append(pick)
    return chosen


def nearest_occupied(anchor_rc, ring_cells):
    """Nearest ring cell to an anchor (Euclidean on the grid)."""
    best = None
    best_d = None
    for rid, rc in ring_cells:
        d = (rc[0] - anchor_rc[0]) ** 2 + (rc[1] - anchor_rc[1]) ** 2
        if best_d is None or d < best_d:
            best_d = d
            best = (rid, rc)
    return best


def rebuild_level(level):
    level_id = level["id"]
    # Strip any previously generated anchors/clips/interlocks for idempotency.
    level["pieces"] = [p for p in level["pieces"]
                       if p.get("bodyType") != "closedAnchor"]
    level.pop("clips", None)
    level.pop("interlocks", None)

    ring_by_id = {p["id"]: p for p in level["pieces"]}
    ring_cells = [(p["id"], parse_cell(p["cell"])) for p in level["pieces"]]

    # 1. Anchors -------------------------------------------------------------
    anchors = []
    target = anchor_target(level_id)
    anchor_cells = choose_anchor_cells(level, target)
    for idx, rc in enumerate(anchor_cells, start=1):
        anchors.append({
            "id": f"A{idx}",
            "kind": "silver",
            "cell": cell_name(*rc),
            "exitDirection": "N",
            "requires": [],
            "bodyType": "closedAnchor",
            "removable": False,
        })
    level["pieces"].extend(anchors)

    clips = []
    interlocks = []

    # 2. Dependency clips + interlocks --------------------------------------
    # Each blocker clip sits at the geometric contact point between the blocker
    # ring and the ring it holds (contactPointMode=betweenCenters), reads "over"
    # the blocked ring, and rolls with its (open) owner.
    for p in level["pieces"]:
        blocked = p["id"]
        blocked_rc = parse_cell(p["cell"])
        blocked_kind = p.get("kind")
        blocked_exit = EXIT_ANGLE.get(p.get("exitDirection"), 0.0)
        for blocker in p.get("requires", []):
            blocker_piece = ring_by_id[blocker]
            blocker_rc = parse_cell(blocker_piece["cell"])
            angle = scene_angle(blocker_rc, blocked_rc)
            # The blocker lies in the blocked ring's escape path when it sits
            # roughly opposite the blocked ring's exit.
            blocked_to_blocker = (angle + 180.0) % 360.0
            blocks_exit = angular_distance(blocked_to_blocker, blocked_exit) <= 60.0
            is_knot = blocked_kind == "copper" and blocker_piece.get("kind") == "copper"
            clip_id = f"K_{blocker}_{blocked}"
            clips.append({
                "id": clip_id,
                "ownerRingId": blocker,
                "angleDegrees": angle,
                "material": "inherited",
                "kind": "bridge" if is_knot else "blocker",
                "blocksRingIds": [blocked],
                "visualWidthScale": 1.15 if is_knot else 1.0,
                "rotatesWithOwner": True,
                "depthRole": "bridge" if is_knot else "over",
                "contactRingId": blocked,
                "contactPointMode": "betweenCenters",
                "visualLayer": "foreground",
                "clampStyle": "bridgeBand" if is_knot else "rivetedBand",
                "blocksExitDirection": bool(blocks_exit),
            })
            interlocks.append({
                "id": f"IL_{blocker}_{blocked}",
                "blockerRingId": blocker,
                "blockedRingId": blocked,
                "blockerClipId": clip_id,
                "contactAngleDegrees": angle,
                "description": (
                    f"{blocked} is caught by {blocker}'s clamp until "
                    f"{blocker} is pulled free."
                ),
                "visualContactMode": "ringHeldByBridge" if is_knot else "clipBlocksGap",
                "requiredGapClearanceAngleDegrees": 30.0,
                "contactDescription": (
                    f"Rotate {blocked}'s gap clear of {blocker}'s clamp, then pull."
                ),
            })

    # 3. Anchor connector clips ---------------------------------------------
    # Each anchor gets a clamp toward its nearest neighbour(s) so it reads as
    # wedged into the grid. Later levels get a second clip for a denser look.
    extra = 2 if level_id >= 11 else 1
    for anchor in anchors:
        a_rc = parse_cell(anchor["cell"])
        # Candidate neighbours: all rings sorted by distance.
        candidates = sorted(
            ring_cells,
            key=lambda rc: (rc[1][0] - a_rc[0]) ** 2 + (rc[1][1] - a_rc[1]) ** 2,
        )
        used = 0
        for rid, rc in candidates:
            if used >= extra:
                break
            angle = scene_angle(a_rc, rc)
            clips.append({
                "id": f"K_{anchor['id']}_{rid}",
                "ownerRingId": anchor["id"],
                "angleDegrees": angle,
                "material": "inherited",
                "kind": "connector",
                "blocksRingIds": [],
                "visualWidthScale": 1.1,
                "rotatesWithOwner": False,
                "depthRole": "connector",
                "contactRingId": rid,
                "contactPointMode": "betweenCenters",
                "visualLayer": "midground",
                "clampStyle": "wideBand",
                "blocksExitDirection": False,
            })
            used += 1

    level["clips"] = clips
    level["interlocks"] = interlocks
    return len(anchors), len(clips), len(interlocks)


def main():
    with open(PACK, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    total_anchors = 0
    for level in data["levels"]:
        a, c, il = rebuild_level(level)
        total_anchors += a
        print(f"Level {level['id']:>2}: anchors={a} clips={c} interlocks={il}")

    with open(PACK, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")

    print(f"\nUpdated {len(data['levels'])} levels, {total_anchors} anchors total.")


if __name__ == "__main__":
    main()
