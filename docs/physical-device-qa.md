# Physical-device QA — Ring Knot iOS

A hands-on checklist for the owner to run on a real iPhone before a TestFlight
build. The simulator covers logic and layout; only a device confirms the rotation
*feel* and the haptics.

## Build status (as prepared in Phase 4B)

A device build was **not** produced in this phase: the project ships with
`DEVELOPMENT_TEAM = ""`, `CODE_SIGNING_ALLOWED = NO`, and
`CODE_SIGNING_REQUIRED = NO` (simulator-only), and the only paired iPhone
(`GB`, iOS 26.5) was **offline** at build time (`xcrun xctrace list devices`).
This is expected and not a phase blocker — it is **owner-needed** signing work.

To build to a device, set in `ios/RingKnot/project.yml` (then `xcodegen generate`):

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "<YOUR_TEAM_ID>"
    CODE_SIGNING_ALLOWED: YES
    CODE_SIGNING_REQUIRED: YES
    CODE_SIGN_STYLE: Automatic
```

then build with a device destination:

```bash
xcodebuild -scheme RingKnot -destination 'platform=iOS,name=<Your iPhone>' \
  -configuration Debug build
```

## Manual test checklist

Run on a paired, unlocked iPhone with the app freshly installed.

### Core rotation mechanic (Level 1)
- [ ] First silver ring starts with its gap visibly **off** the exit.
- [ ] Rolling a finger around the ring rotates it smoothly (no jitter, no lag).
- [ ] The gap **snaps** gently onto the exit with a light haptic + green "ready" ring.
- [ ] Pulling **before** aligning is refused ("rotate first" nudge) — ring stays.
- [ ] Pulling the **aligned** ring outward releases it with a success haptic.
- [ ] Trying a **blocked** ring (copper before its silver) shows blocked feedback.
- [ ] Freeing the copper ring completes Level 1; completion screen appears.

### Feel across the curve
- [ ] Level 5 (tolerance 22°) feels forgiving.
- [ ] Level 10 (tolerance 18°) still smooth, slightly tighter.
- [ ] Level 20 (tolerance 12°) precise but not frustrating (unlock via Settings →
      Reset is not enough; play through or use a debug build).
- [ ] Copper rings roll and release as smoothly as silver.

### Settings & accessibility
- [ ] Sound toggle silences/enables SFX immediately.
- [ ] Haptics toggle stops/starts the rotation + release haptics immediately.
- [ ] Reduce Motion (iOS Settings → Accessibility): static highlight, no pulsing
      ready-ring, no particles, instant snap; gameplay still works.
- [ ] VoiceOver: the board announces rings remaining and the held ring's alignment;
      the "Rotate ring to opening" rotor action aligns the next ring; "Show Hint"
      and "Restart Level" work; tutorial text is read aloud.
- [ ] Large Dynamic Type (Accessibility text sizes): onboarding and settings
      remain readable/scrollable; HUD and completion buttons stay usable.

### Robustness & persistence
- [ ] Restart level resets rings and the move counter.
- [ ] Reset progress (Settings) clears completion and re-shows onboarding.
- [ ] Force-quit and relaunch: completed levels and best scores persist; settings
      persist.
- [ ] Rotating the device / returning from background does not break the board.

## What to report back

Note any ring that feels sticky to pull, releases too easily during a roll, snaps
too aggressively, or any level whose tolerance feels wrong. Those map directly to
the tuned values in `docs/gameplay/rotatable-rings.md`.
