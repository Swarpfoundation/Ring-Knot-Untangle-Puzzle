# Interlock Visual Style (Phase 6B)

The visual contract for the anchor/blocker-clip board. Everything here is drawn
**procedurally** in SpriteKit/CoreGraphics — no downloaded or copied art.

## Closed anchor style
- Full closed ring (gap `0°`), same silver metal as open rings.
- A heavier dark drop shadow behind it (`addBacking`) so it reads as *planted*
  and immovable.
- Never shows a gap, ready glow, or rotation. Tapping gives a calm steel pulse.

## Open ring style
- Open C-ring with a strong, clearly visible gap (72°).
- Rolls under the player's drag; ready (cyan-green) glow when the gap aligns.

## Blocker clip style
- Small rounded-rectangle clamp band with:
  - brushed-metal vertical gradient (highlight → base → shadow),
  - a raised **bevel** (bright top edge, dark bottom edge),
  - **rivet ridges** (count scales with clamp width) plus a forged highlight,
  - a crisp dark outline,
  - a soft **contact shadow** on the ring the clamp crosses.
- `clampStyle`: `shortBand` (default open-ring blocker), `rivetedBand`
  (dependency blockers), `wideBand` (anchor connectors), `bridgeBand`
  (copper-knot bridges, widest with the most ridges).
- Dependency blockers use `contactPointMode: betweenCenters` so the clamp sits
  on the contact rim between the two rings, not arbitrarily on the owner tube.

## Connector clip style
- Decorative clamp joining an anchor to a neighbour (`kind: connector`,
  `depthRole: connector`, `wideBand`). Communicates the tight grid without
  gating a dependency. Sits at mid-depth.

## Over / under layering
- Render order is authoritative: `SKView.ignoresSiblingOrder = true`.
- Clip band z within its layer by `depthRole`: `over` (+6) for blockers, `bridge`
  (+5) for knot bridges, `connector` (+1) at mid-depth, `under` (−3) tucked below.
- Blocker clamps therefore read **above** the rings they hold; connectors tuck in.

## Contact shadow rules
- Each clamp casts a soft dark ellipse just beneath/below it (`zPosition − 0.5`),
  so where a clip crosses a ring there is a believable shadow.

## Copper knot
- Warm additive sheen behind copper rings (gently pulsing unless Reduce Motion),
  marking the knot as the premium centre. Copper-to-copper holds use `bridgeBand`
  clips and `ringHeldByBridge` interlocks.

## Level 1 readability rules
- Exactly one anchor, one open ring, one copper ring, one obvious blocker clip.
- The first open ring's gap must rotate past its clip to release.
- Tutorial copy: anchors are fixed, clips show where rings are caught, rotate the
  gap clear of the clip, then pull.

## Level 20 density rules
- Dense final-knot grid (4 anchors), but the copper knot stays visually central
  and is never hidden by clips (knot bridges sit at bridge depth, not over the
  copper core). Bands remain legible at phone size.

## Forbidden copied-reference elements
- No copied `E=mc²` layout or readable equation field from the reference.
- No reference hand / stylus / social UI, no Einstein/profile imagery, no ad
  numbers or buttons. Backgrounds stay original, dark, and subtle.
