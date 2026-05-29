#!/usr/bin/env python3
"""Replay validator for the Ring Knot level pack.

Loads shared/levels/ring_unlock_level_pack_v1.json and, for every level,
faithfully replays its solution path using the same rules as the in-app
MoveValidator / GameState. It fails (non-zero exit, clear message) if:

  * a ring dependency references a missing ring
  * a solution step references a missing ring
  * a blocked ring (one with unmet requires) is removable before its
    prerequisites are cleared
  * a solution step is invalid when replayed in order
  * a level is not fully cleared after applying its whole solution path

Standard library only. No network, no third-party packages.

Run:  python3 tools/replay_validator.py
Self-test: python3 tools/replay_validator.py --selftest
"""

import json
import os
import sys

VALID_DIRECTIONS = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}

DEFAULT_PACK = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "shared", "levels", "ring_unlock_level_pack_v1.json",
)


class ValidationError(Exception):
    pass


# --- Faithful port of MoveValidator.evaluate -------------------------------

def evaluate(ring, drag_direction, cleared_ids):
    """Mirror of the Swift MoveValidator. `ring` is None if unknown."""
    if ring is None:
        return "unknownRing"
    if ring["id"] in cleared_ids:
        return "alreadyCleared"
    missing = [r for r in ring["requires"] if r not in cleared_ids]
    if missing:
        return "blockedByPrerequisite"
    if drag_direction != ring["exitDirection"]:
        return "wrongDirection"
    return "accepted"


def validate_level(level):
    level_id = level.get("id", "?")
    pieces = level.get("pieces", [])
    rings = {}
    for piece in pieces:
        rid = piece.get("id")
        if rid is None:
            raise ValidationError(f"Level {level_id}: piece missing id")
        if rid in rings:
            raise ValidationError(f"Level {level_id}: duplicate ring id '{rid}'")
        direction = piece.get("exitDirection")
        if direction not in VALID_DIRECTIONS:
            raise ValidationError(
                f"Level {level_id}: ring '{rid}' invalid exitDirection '{direction}'")
        rings[rid] = {
            "id": rid,
            "kind": piece.get("kind"),
            "exitDirection": direction,
            "requires": list(piece.get("requires", []) or []),
        }

    # Dependencies must reference existing rings.
    for ring in rings.values():
        for dep in ring["requires"]:
            if dep not in rings:
                raise ValidationError(
                    f"Level {level_id}: ring '{ring['id']}' requires missing ring '{dep}'")

    # Solution must reference existing rings and have valid drag directions.
    solution = level.get("solution", [])
    for step in solution:
        sid = step.get("id")
        drag = step.get("drag")
        if sid not in rings:
            raise ValidationError(
                f"Level {level_id}: solution references missing ring '{sid}'")
        if drag not in VALID_DIRECTIONS:
            raise ValidationError(
                f"Level {level_id}: solution step '{sid}' invalid drag '{drag}'")

    # Blocked rings must NOT be removable before their prerequisites.
    for ring in rings.values():
        if ring["requires"]:
            outcome = evaluate(ring, ring["exitDirection"], set())
            if outcome == "accepted":
                raise ValidationError(
                    f"Level {level_id}: blocked ring '{ring['id']}' is removable "
                    f"before its prerequisites {ring['requires']}")

    # Replay the solution in order; every step must be accepted.
    cleared = set()
    for index, step in enumerate(solution):
        sid = step["id"]
        drag = step["drag"]
        outcome = evaluate(rings.get(sid), drag, cleared)
        if outcome != "accepted":
            raise ValidationError(
                f"Level {level_id}: solution step {index + 1} ('{sid}' drag {drag}) "
                f"was rejected with '{outcome}'")
        cleared.add(sid)

    # The level must be fully cleared after the solution path.
    if len(cleared) != len(rings):
        leftover = sorted(set(rings) - cleared)
        raise ValidationError(
            f"Level {level_id}: not complete after solution path; "
            f"{len(cleared)}/{len(rings)} cleared, leftover {leftover}")

    return len(rings)


def validate_pack(path):
    if not os.path.isfile(path):
        raise ValidationError(f"Level pack not found: {path}")
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    levels = data.get("levels")
    if not isinstance(levels, list) or not levels:
        raise ValidationError("Level pack has no levels array")

    seen_ids = set()
    for level in levels:
        lid = level.get("id")
        if lid in seen_ids:
            raise ValidationError(f"Duplicate level id {lid}")
        seen_ids.add(lid)
        ring_count = validate_level(level)
        print(f"OK    Level {lid:>2}  '{level.get('name','?')}'  "
              f"rings={ring_count}  solution={len(level.get('solution', []))}")
    return len(levels)


# --- Self-test of the validator itself -------------------------------------

def selftest():
    def expect_fail(level, needle):
        try:
            validate_level(level)
        except ValidationError as err:
            assert needle in str(err), f"wrong error: {err}"
            return
        raise AssertionError(f"expected failure containing '{needle}'")

    # Valid mini level.
    good = {
        "id": 99, "name": "t", "pieces": [
            {"id": "S1", "kind": "silver", "exitDirection": "N", "requires": []},
            {"id": "C1", "kind": "copper", "exitDirection": "E", "requires": ["S1"]},
        ],
        "solution": [{"id": "S1", "drag": "N"}, {"id": "C1", "drag": "E"}],
    }
    assert validate_level(good) == 2

    expect_fail({**good, "pieces": [
        {"id": "C1", "kind": "copper", "exitDirection": "E", "requires": ["MISSING"]}],
        "solution": [{"id": "C1", "drag": "E"}]}, "missing ring")

    expect_fail({**good, "solution": [{"id": "GHOST", "drag": "E"}]},
                "missing ring 'GHOST'")

    # Wrong drag direction on replay.
    expect_fail({**good, "solution": [{"id": "S1", "drag": "S"},
                                      {"id": "C1", "drag": "E"}]}, "rejected")

    # Solution out of order (C1 before its prerequisite S1) -> rejected.
    expect_fail({**good, "solution": [{"id": "C1", "drag": "E"},
                                      {"id": "S1", "drag": "N"}]}, "rejected")

    # Incomplete solution path.
    expect_fail({**good, "solution": [{"id": "S1", "drag": "N"}]}, "not complete")

    print("self-test passed")


def main(argv):
    if "--selftest" in argv:
        selftest()
        return 0
    path = DEFAULT_PACK
    for arg in argv[1:]:
        if not arg.startswith("-"):
            path = arg
    try:
        count = validate_pack(path)
    except (ValidationError, json.JSONDecodeError) as err:
        print(f"FAIL  {err}", file=sys.stderr)
        return 1
    print(f"\nValidated {count} levels — all solution paths replay to completion.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
