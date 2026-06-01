# Physical-device QA — results

## Outcome: not run (blocked on device availability + signing)

A physical-device pass could **not** be performed in this phase. This is an
owner-side blocker, not an engineering defect.

### Device availability

`xcrun xctrace list devices` showed:

- The host Mac itself.
- One paired iPhone — **`GB` (iOS 26.5)** — listed under **Devices Offline**.

No usable, online, paired iPhone was available at run time.

### Signing status

The project ships simulator-only:

- `DEVELOPMENT_TEAM = ""`
- `CODE_SIGNING_ALLOWED = NO`
- `CODE_SIGNING_REQUIRED = NO`

A device build therefore cannot be produced without owner-supplied signing.

### Exact blocker

1. No online paired device, **and**
2. No `DEVELOPMENT_TEAM` / signing identity configured.

Either alone blocks an install-and-run on hardware.

### Owner action required

1. Bring the iPhone online and trust the Mac.
2. Set `DEVELOPMENT_TEAM` + automatic signing in `ios/RingKnot/project.yml`
   (`xcodegen generate`) — see `testflight-owner-checklist.md`.
3. Build to the device:
   `xcodebuild -scheme RingKnot -destination 'platform=iOS,name=<iPhone>' -configuration Debug build`
4. Run the manual checklist below and record pass/fail.

## Manual checklist (to be completed by the owner on device)

The simulator covers logic and layout; only a device confirms rotation *feel* and
real haptics. Full steps live in `docs/physical-device-qa.md`; the headline items:

- [ ] Onboarding shows the rotation walkthrough.
- [ ] Level 1: ring starts unaligned; rolling rotates it smoothly.
- [ ] Pull **before** alignment is refused.
- [ ] Pull **after** alignment releases the ring (success haptic).
- [ ] Copper ring also requires alignment.
- [ ] Level 1 completes; completion screen appears.
- [ ] Settings: sound toggle, haptics toggle each take effect immediately.
- [ ] Restart level; reset progress; relaunch persistence.
- [ ] Reduce Motion simplifies effects.
- [ ] VoiceOver: board alignment summary + "Rotate ring to opening" action.
- [ ] Large Dynamic Type stays readable.

## Simulator coverage already in place

Everything above except real-hardware *feel*/haptics is exercised on the iPhone 17
Pro simulator (and layout on iPhone 17e) via the automated unit + UI suites and
the genuine screenshots in `docs/screenshots/final-ios/`.
