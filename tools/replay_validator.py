#!/usr/bin/env python3
"""Replay validator for the Ring Knot level pack.

Loads shared/levels/ring_unlock_level_pack_v1.json and, for every level,
faithfully replays its solution path using the same rules as the in-app
MoveValidator / GameState — including the Phase 4A rotatable-ring mechanic:
each ring must be rolled so its gap is aligned with its exit direction before it
can be pulled out.

It fails (non-zero exit, clear message) if:

  * a ring dependency references a missing ring
  * a solution step references a missing ring
  * a ring has an invalid or missing initial gap angle (and no derivable fallback)
  * a level has an invalid alignment tolerance
  * a ring starts already aligned (the mechanic requires a deliberate rotation)
  * a blocked ring (one with unmet requires) is removable before its
    prerequisites are cleared, even once its gap is aligned
  * a solution step would remove a ring whose gap is not aligned
  * a solution step is invalid when replayed in order
  * a level is not fully cleared after applying its whole solution path

Standard library only. No network, no third-party packages.

Run:  python3 tools/replay_validator.py
Self-test: python3 tools/replay_validator.py --selftest
"""

import json
import math
import os
import sys

VALID_DIRECTIONS = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}

# Gap angle (screen convention, CCW from East) at which a gap faces each exit.
EXIT_ANGLE = {
    "E": 0.0, "NE": 45.0, "N": 90.0, "NW": 135.0,
    "W": 180.0, "SW": 225.0, "S": 270.0, "SE": 315.0,
}

DEFAULT_PACK = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "shared", "levels", "ring_unlock_level_pack_v1.json",
)


class ValidationError(Exception):
    pass


# --- Angle maths (mirror of RingRotation.swift) ----------------------------

def normalize_degrees(deg):
    wrapped = math.fmod(deg, 360.0)
    return wrapped + 360.0 if wrapped < 0 else wrapped


def shortest_distance(a, b):
    delta = normalize_degrees(b) - normalize_degrees(a)
    if delta > 180:
        delta -= 360
    if delta <= -180:
        delta += 360
    return delta


def is_aligned(gap, target, tolerance):
    return abs(shortest_distance(gap, target)) <= tolerance


def derived_initial_gap(ring_id, target):
    """Deterministic fallback when a ring omits initialGapAngle. Mirrors the
    intent of Ring.derivedInitialGapAngle: a stable per-id offset that is never
    aligned. Only used when the JSON lacks an explicit value."""
    seed = 0
    for ch in ring_id:
        seed = seed * 31 + ord(ch)
    magnitude = 50 + (abs(seed) % 81)            # 50…130
    sign = 1 if (abs(seed) // 81) % 2 == 0 else -1
    return normalize_degrees(target + sign * magnitude)


def tolerance_default(level_id):
    if level_id is None:
        return 22.0
    if level_id < 6:
        return 22.0
    if level_id < 11:
        return 18.0
    if level_id < 16:
        return 15.0
    return 12.0


def min_anchors(level_id):
    """Minimum closed anchors expected per level band (Phase 6A curve)."""
    if level_id is None:
        return 1
    if level_id <= 5:
        return 1
    if level_id <= 10:
        return 1
    if level_id <= 15:
        return 2
    return 3


# --- Faithful port of MoveValidator ----------------------------------------

def evaluate_release(ring, gap_angle, cleared_ids, tolerance):
    """Mirror of MoveValidator.evaluateRelease. `ring` is None if unknown."""
    if ring is None:
        return "unknownRing"
    if ring["id"] in cleared_ids:
        return "alreadyCleared"
    missing = [r for r in ring["requires"] if r not in cleared_ids]
    if missing:
        return "blockedByPrerequisite"
    if not is_aligned(gap_angle, ring["target"], tolerance):
        return "notAligned"
    return "accepted"


def validate_level(level):
    level_id = level.get("id", "?")

    tolerance = level.get("alignmentToleranceDegrees")
    if tolerance is None:
        tolerance = tolerance_default(level_id)
    if not isinstance(tolerance, (int, float)) or not math.isfinite(tolerance) \
            or tolerance <= 0 or tolerance > 90:
        raise ValidationError(
            f"Level {level_id}: invalid alignmentToleranceDegrees {tolerance!r}")

    pieces = level.get("pieces", [])
    rings = {}
    anchors = set()        # ids of non-removable closed anchors
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
        target = EXIT_ANGLE[direction]

        body_type = piece.get("bodyType", "openRing")
        if body_type not in ("openRing", "closedAnchor"):
            raise ValidationError(
                f"Level {level_id}: ring '{rid}' invalid bodyType '{body_type}'")
        is_anchor = body_type == "closedAnchor"
        removable = piece.get("removable", not is_anchor)
        if is_anchor and removable:
            # Anchors default non-removable; an explicitly removable anchor would
            # be a future feature, not used in the shipped pack.
            raise ValidationError(
                f"Level {level_id}: closed anchor '{rid}' is marked removable")
        if is_anchor:
            anchors.add(rid)

        # Anchors are full closed rings: no gap, never rolled or released, so the
        # "must start misaligned" rule does not apply to them.
        gap = None
        if not is_anchor:
            gap = piece.get("initialGapAngle")
            if gap is None:
                gap = derived_initial_gap(rid, target)
            if not isinstance(gap, (int, float)) or not math.isfinite(gap):
                raise ValidationError(
                    f"Level {level_id}: ring '{rid}' invalid initialGapAngle {gap!r}")
            gap = normalize_degrees(float(gap))
            if is_aligned(gap, target, tolerance):
                raise ValidationError(
                    f"Level {level_id}: ring '{rid}' starts already aligned "
                    f"(gap {gap}, target {target}, tol {tolerance}); it must require rotation")

        rings[rid] = {
            "id": rid,
            "kind": piece.get("kind"),
            "exitDirection": direction,
            "target": target,
            "initialGap": gap,
            "requires": list(piece.get("requires", []) or []),
            "removable": removable,
            "isAnchor": is_anchor,
        }

    # Every level must carry at least the band's minimum closed anchors.
    need = min_anchors(level_id)
    if len(anchors) < need:
        raise ValidationError(
            f"Level {level_id}: has {len(anchors)} closed anchor(s); "
            f"needs at least {need} for its band")

    # Dependencies must reference existing rings.
    for ring in rings.values():
        for dep in ring["requires"]:
            if dep not in rings:
                raise ValidationError(
                    f"Level {level_id}: ring '{ring['id']}' requires missing ring '{dep}'")

    # --- Clips ------------------------------------------------------------
    clips = {}
    for clip in level.get("clips", []):
        cid = clip.get("id")
        if cid is None:
            raise ValidationError(f"Level {level_id}: clip missing id")
        if cid in clips:
            raise ValidationError(f"Level {level_id}: duplicate clip id '{cid}'")
        owner = clip.get("ownerRingId")
        if owner not in rings:
            raise ValidationError(
                f"Level {level_id}: clip '{cid}' has unknown ownerRingId '{owner}'")
        for blocked in clip.get("blocksRingIds", []) or []:
            if blocked not in rings:
                raise ValidationError(
                    f"Level {level_id}: clip '{cid}' blocks unknown ring '{blocked}'")
        clips[cid] = clip

    # Every closed anchor must carry at least one clip.
    clipped_owners = {c.get("ownerRingId") for c in clips.values()}
    for aid in anchors:
        if aid not in clipped_owners:
            raise ValidationError(
                f"Level {level_id}: closed anchor '{aid}' has no blocker clip")

    # --- Interlocks -------------------------------------------------------
    interlocks = level.get("interlocks", [])
    # An interlock "covers" a dependency edge (blocker -> blocked).
    covered_edges = set()
    for lock in interlocks:
        lid = lock.get("id", "?")
        blocker = lock.get("blockerRingId")
        blocked = lock.get("blockedRingId")
        clip_id = lock.get("blockerClipId")
        for ref in (blocker, blocked):
            if ref not in rings:
                raise ValidationError(
                    f"Level {level_id}: interlock '{lid}' references unknown ring '{ref}'")
        if clip_id not in clips:
            raise ValidationError(
                f"Level {level_id}: interlock '{lid}' references unknown clip '{clip_id}'")
        covered_edges.add((blocker, blocked))

    # Every dependency edge must be visually explained by an interlock/clip,
    # unless the level opts into abstractOnly (not used in the shipped pack).
    if not level.get("abstractOnly", False):
        for ring in rings.values():
            for dep in ring["requires"]:
                if (dep, ring["id"]) not in covered_edges:
                    raise ValidationError(
                        f"Level {level_id}: dependency '{dep}' -> '{ring['id']}' "
                        f"has no matching interlock/clip (set abstractOnly to allow)")

    # Solution must reference existing, removable, non-anchor rings only.
    solution = level.get("solution", [])
    for step in solution:
        sid = step.get("id")
        drag = step.get("drag")
        if sid not in rings:
            raise ValidationError(
                f"Level {level_id}: solution references missing ring '{sid}'")
        if rings[sid]["isAnchor"] or not rings[sid]["removable"]:
            raise ValidationError(
                f"Level {level_id}: solution references non-removable anchor '{sid}'")
        if drag not in VALID_DIRECTIONS:
            raise ValidationError(
                f"Level {level_id}: solution step '{sid}' invalid drag '{drag}'")

    # Blocked rings must NOT be removable before their prerequisites — even when
    # their gap is rolled perfectly onto the exit (alignment alone is not enough).
    for ring in rings.values():
        if ring["isAnchor"]:
            continue
        if ring["requires"]:
            outcome = evaluate_release(ring, ring["target"], set(), tolerance)
            if outcome == "accepted":
                raise ValidationError(
                    f"Level {level_id}: blocked ring '{ring['id']}' is removable "
                    f"before its prerequisites {ring['requires']}")

    # Anchors must never be releasable (engine returns notRemovable; here we just
    # assert they are not in the removable set the replay will clear).
    removable_ids = {rid for rid, r in rings.items() if r["removable"]}

    # Replay the solution in order. Each step: roll the gap onto the exit, confirm
    # it is now aligned, confirm a release would otherwise be rejected at the
    # ring's *initial* (misaligned) gap, then release.
    cleared = set()
    for index, step in enumerate(solution):
        sid = step["id"]
        ring = rings[sid]

        pre = evaluate_release(ring, ring["initialGap"], cleared, tolerance)
        if pre == "accepted":
            raise ValidationError(
                f"Level {level_id}: solution step {index + 1} ('{sid}') would remove "
                f"the ring at its unaligned initial gap — alignment not enforced")

        aligned_gap = ring["target"]
        outcome = evaluate_release(ring, aligned_gap, cleared, tolerance)
        if outcome != "accepted":
            raise ValidationError(
                f"Level {level_id}: solution step {index + 1} ('{sid}') rejected "
                f"after alignment with '{outcome}'")
        cleared.add(sid)

    # All removable rings must be gone; all anchors must remain on the board.
    if cleared != removable_ids:
        missing = sorted(removable_ids - cleared)
        raise ValidationError(
            f"Level {level_id}: solution did not clear all removable rings; "
            f"leftover {missing}")
    remaining_anchors = anchors - cleared
    if remaining_anchors != anchors:
        raise ValidationError(
            f"Level {level_id}: an anchor was removed by the solution path")

    return len(rings), len(anchors), len(clips)


def validate_pack(path):
    if not os.path.isfile(path):
        raise ValidationError(f"Level pack not found: {path}")
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    levels = data.get("levels")
    if not isinstance(levels, list) or not levels:
        raise ValidationError("Level pack has no levels array")

    if len(levels) != 20:
        raise ValidationError(f"Expected exactly 20 levels, found {len(levels)}")

    seen_ids = set()
    for level in levels:
        lid = level.get("id")
        if lid in seen_ids:
            raise ValidationError(f"Duplicate level id {lid}")
        seen_ids.add(lid)
        ring_count, anchor_count, clip_count = validate_level(level)
        print(f"OK    Level {lid:>2}  '{level.get('name','?')}'  "
              f"tol={level.get('alignmentToleranceDegrees', tolerance_default(lid))}°  "
              f"rings={ring_count}  anchors={anchor_count}  clips={clip_count}  "
              f"solution={len(level.get('solution', []))}")
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

    def anchor(rid="A1", cell_dir="N"):
        return {"id": rid, "kind": "silver", "exitDirection": cell_dir,
                "requires": [], "bodyType": "closedAnchor", "removable": False}

    # Valid mini level (band 1-5 → 1 anchor): S1 (N, 150° = 60° off), C1 (E, 285°),
    # one closed anchor A1 with a connector clip, and an interlock covering S1->C1.
    good = {
        "id": 3, "name": "t", "alignmentToleranceDegrees": 22, "pieces": [
            {"id": "S1", "kind": "silver", "exitDirection": "N",
             "requires": [], "initialGapAngle": 150},
            {"id": "C1", "kind": "copper", "exitDirection": "E",
             "requires": ["S1"], "initialGapAngle": 285},
            anchor("A1"),
        ],
        "clips": [
            {"id": "K1", "ownerRingId": "S1", "angleDegrees": 270,
             "kind": "blocker", "blocksRingIds": ["C1"]},
            {"id": "KA", "ownerRingId": "A1", "angleDegrees": 0,
             "kind": "connector", "blocksRingIds": []},
        ],
        "interlocks": [
            {"id": "IL1", "blockerRingId": "S1", "blockedRingId": "C1",
             "blockerClipId": "K1", "contactAngleDegrees": 270},
        ],
        "solution": [{"id": "S1", "drag": "N"}, {"id": "C1", "drag": "E"}],
    }
    rings, anchors, clips = validate_level(good)
    assert (rings, anchors, clips) == (3, 1, 2), (rings, anchors, clips)

    # Direct rotation maths.
    assert normalize_degrees(-90) == 270
    assert normalize_degrees(450) == 90
    assert abs(shortest_distance(350, 10) - 20) < 1e-9
    assert abs(shortest_distance(10, 350) + 20) < 1e-9
    assert is_aligned(95, 90, 22) and not is_aligned(150, 90, 22)

    # Releasing a ring at its unaligned initial gap is rejected.
    ringS1 = {"id": "S1", "requires": [], "target": 90.0}
    assert evaluate_release(ringS1, 150, set(), 22) == "notAligned"
    assert evaluate_release(ringS1, 90, set(), 22) == "accepted"

    # Missing dependency / solution ghost / out-of-order / incomplete.
    expect_fail({**good, "pieces": [
        {"id": "C1", "kind": "copper", "exitDirection": "E",
         "requires": ["MISSING"], "initialGapAngle": 285}, anchor("A1")],
        "clips": [{"id": "KA", "ownerRingId": "A1", "angleDegrees": 0}],
        "interlocks": [],
        "solution": [{"id": "C1", "drag": "E"}]}, "missing ring")
    expect_fail({**good, "solution": [{"id": "GHOST", "drag": "E"}]},
                "missing ring 'GHOST'")
    expect_fail({**good, "solution": [{"id": "C1", "drag": "E"},
                                      {"id": "S1", "drag": "N"}]}, "blocked")
    expect_fail({**good, "solution": [{"id": "S1", "drag": "N"}]},
                "did not clear all removable")

    # A ring that starts already aligned must fail.
    expect_fail({**good, "pieces": [
        {"id": "S1", "kind": "silver", "exitDirection": "N",
         "requires": [], "initialGapAngle": 90},
        {"id": "C1", "kind": "copper", "exitDirection": "E",
         "requires": ["S1"], "initialGapAngle": 285}, anchor("A1")]}, "already aligned")

    # Invalid gap angle and invalid tolerance.
    expect_fail({**good, "pieces": [
        {"id": "S1", "kind": "silver", "exitDirection": "N",
         "requires": [], "initialGapAngle": "oops"},
        {"id": "C1", "kind": "copper", "exitDirection": "E",
         "requires": ["S1"], "initialGapAngle": 285}, anchor("A1")]},
        "invalid initialGapAngle")
    expect_fail({**good, "alignmentToleranceDegrees": 0}, "invalid alignmentToleranceDegrees")
    expect_fail({**good, "alignmentToleranceDegrees": 120}, "invalid alignmentToleranceDegrees")

    # --- Phase 6A anchor / clip / interlock rules -------------------------

    # A level with no closed anchor fails the band minimum.
    expect_fail({**good, "pieces": [
        {"id": "S1", "kind": "silver", "exitDirection": "N",
         "requires": [], "initialGapAngle": 150},
        {"id": "C1", "kind": "copper", "exitDirection": "E",
         "requires": ["S1"], "initialGapAngle": 285}]}, "closed anchor")

    # An anchor with no clip fails.
    expect_fail({**good, "clips": [
        {"id": "K1", "ownerRingId": "S1", "angleDegrees": 270,
         "blocksRingIds": ["C1"]}]}, "no blocker clip")

    # A clip with an unknown owner fails.
    expect_fail({**good, "clips": good["clips"] + [
        {"id": "KX", "ownerRingId": "NOPE", "angleDegrees": 0}]}, "unknown ownerRingId")

    # A clip blocking an unknown ring fails.
    expect_fail({**good, "clips": good["clips"] + [
        {"id": "KY", "ownerRingId": "S1", "angleDegrees": 0,
         "blocksRingIds": ["NOPE"]}]}, "blocks unknown ring")

    # An interlock referencing an unknown clip fails.
    expect_fail({**good, "interlocks": [
        {"id": "ILX", "blockerRingId": "S1", "blockedRingId": "C1",
         "blockerClipId": "GHOSTCLIP", "contactAngleDegrees": 0}]},
        "unknown clip")

    # A dependency with no interlock fails (unless abstractOnly).
    expect_fail({**good, "interlocks": []}, "no matching interlock")
    abstract = {**good, "interlocks": [], "abstractOnly": True}
    assert validate_level(abstract)[1] == 1   # anchors still present

    # The solution may not reference a non-removable anchor.
    expect_fail({**good, "solution": good["solution"] + [{"id": "A1", "drag": "N"}]},
                "non-removable anchor")

    # An explicitly removable closed anchor is rejected.
    expect_fail({**good, "pieces": [
        {"id": "S1", "kind": "silver", "exitDirection": "N",
         "requires": [], "initialGapAngle": 150},
        {"id": "C1", "kind": "copper", "exitDirection": "E",
         "requires": ["S1"], "initialGapAngle": 285},
        {"id": "A1", "kind": "silver", "exitDirection": "N", "requires": [],
         "bodyType": "closedAnchor", "removable": True}]}, "marked removable")

    # Anchors remain on the board after a full solution replay (completion ignores
    # them): `good` clears S1+C1 but keeps A1, and validate_level returned cleanly.

    # Missing initialGapAngle falls back to a derived, non-aligned angle.
    fallback = {
        "id": 4, "name": "f", "alignmentToleranceDegrees": 22, "pieces": [
            {"id": "S1", "kind": "silver", "exitDirection": "N", "requires": []},
            {"id": "C1", "kind": "copper", "exitDirection": "E", "requires": ["S1"]},
            anchor("A1"),
        ],
        "clips": [
            {"id": "K1", "ownerRingId": "S1", "angleDegrees": 270, "blocksRingIds": ["C1"]},
            {"id": "KA", "ownerRingId": "A1", "angleDegrees": 0},
        ],
        "interlocks": [
            {"id": "IL1", "blockerRingId": "S1", "blockedRingId": "C1",
             "blockerClipId": "K1", "contactAngleDegrees": 270},
        ],
        "solution": [{"id": "S1", "drag": "N"}, {"id": "C1", "drag": "E"}],
    }
    assert validate_level(fallback)[0] == 3

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
    print(f"\nValidated {count} levels — every ring rotates into alignment and "
          f"all solution paths replay to completion.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
