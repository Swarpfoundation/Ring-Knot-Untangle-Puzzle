# Physical-Device QA Checklist — Ring Knot v1.0.0

## Current status: PENDING (blocked)
No physical iPhone is connected to this environment and signing is not configured
(`DEVELOPMENT_TEAM` empty, simulator-only). `xcrun xctrace list devices` shows **no
connected physical devices**. A Debug device build was therefore **not attempted** —
signing was not hacked and QA was **not** marked as passed.

To run this checklist the owner needs: a real iPhone, a Team ID + provisioning
profile for `com.swarpfoundation.ringknot`, and a wired/trusted device. All
automated validation (build, 74 unit/UI tests, replay validator, Release artifact
scan) has passed on the **iPhone 17 Pro simulator (iOS 26.4.1)**.

## Manual QA checklist (run on a real device once signing is available)

### First run & onboarding
- [ ] First launch shows onboarding (anchors, clips, rotate-then-pull).
- [ ] Skip and Start both work; onboarding does not reappear on next launch.

### Level 1 tutorial
- [ ] Level 1 shows the tutorial copy (anchor is fixed / rotate gap clear of clip).
- [ ] Tutorial advances rotate → pull → blockers and does not block gameplay.

### Core mechanic
- [ ] Open ring rotates smoothly under a circular drag.
- [ ] The visible gap rotates with the ring.
- [ ] Pull **before** alignment fails with a "rotate first" nudge (no removal).
- [ ] Align the gap with the blocker clip / exit → ready glow appears.
- [ ] Pull **after** alignment succeeds; the ring slides out.
- [ ] Settle "pop" plays as the gap clears the clip.

### Blockers & anchors
- [ ] Pulling a blocked ring flashes the blocker ring + the exact clamp once.
- [ ] Tapping a full anchor ring gives a calm steel pulse, no move counted.
- [ ] Copper knot releases last; freeing it completes the level.

### Completion & readability
- [ ] Level 1 completes; the anchor remains on the board.
- [ ] Level 10 reads clearly (layered interlocks, no clutter).
- [ ] Level 20 reads clearly; copper knot stays visible over the silver bands.

### Settings & persistence
- [ ] Settings sound toggle works and persists.
- [ ] Settings haptics toggle works.
- [ ] Restart level resets the board.
- [ ] Reset progress re-locks levels.
- [ ] Relaunch persists progress / best moves.

### Accessibility
- [ ] Reduce Motion: no pulsing loops/particles; static highlights, instant fades.
- [ ] VoiceOver: board summary states remaining rings + held-ring alignment; the
      "Rotate ring to opening" action works.
- [ ] Large Dynamic Type: HUD, tutorial, settings, and completion remain legible.

### Sign-off
- [ ] Tester name + device + iOS version: `__________`
- [ ] Result: `__________` (do not mark passed unless actually verified on device)
