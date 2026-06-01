# Known Limitations — Ring Knot v1.0.0

Honest, current limitations of the v1 release candidate. None of these are broken
gameplay — every level is solvable and all 20 replay deterministically. They are
rendering/tooling/process notes plus the genuine owner-account blockers.

## Rendering
- **Simulated split-tube occlusion.** Where a band crosses a ring, occlusion is
  drawn with layered z-order + redrawn tube arc-segments + contact shadows
  (deterministic split-arc overlays), **not** per-pixel geometric tube masking. It
  reads as a woven metal puzzle and the copper knot is always kept on top, but it is
  a visual simulation, not a physics/mask simulation.
- **Build-time gap sampling for over-arcs.** A copper ring rotated so its gap lands
  exactly on a crossing can briefly show a tube segment over a gap. Rare and minor.
- **Fixed contact bands.** Contact/bridge clamps are fixed at the contact point (the
  ring's gap rotates past them); they do not roll with the open ring. This is the
  more physically correct behaviour but means contact clips do not spin.

## Tooling / evidence
- **No screen recording from this host.** The headless simulator's render server
  fails with `SimRenderServer.SimulatorError Code=2` during `simctl io recordVideo`,
  so no `.mov` demo was produced. Genuine stills are provided instead; a recording
  can be captured on a host with a stable render server or on a real device.

## Process
- **Physical-device QA pending.** No iPhone is connected and signing is not
  configured, so on-device QA has not been run (see
  `physical-device-qa-checklist.md`). All simulator validation passes.
- **Signing / TestFlight owner-gated.** Team ID, certificates, the App Store Connect
  record, metadata finalisation, and any upload require the owner's Apple account
  (see `testflight-owner-checklist.md`).

## Platform scope
- **iOS only.** No Android client exists yet; the shared level pack
  (`shared/levels/ring_unlock_level_pack_v1.json`) is the cross-platform source of
  truth for when an Android port is built.
