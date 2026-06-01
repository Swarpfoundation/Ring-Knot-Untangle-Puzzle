# Final Screenshot Plan — Ring Knot v1.0.0

Fresh genuine simulator stills captured from merged `main` (commit `0e00835`) on the
**iPhone 17 Pro simulator (iOS 26.4.1)** live in `docs/screenshots/final-ios-v1/`.
They are the basis for the App Store screenshot set; the owner exports final-sized
images per Apple's required device classes.

## Captured stills (`docs/screenshots/final-ios-v1/`)
| File | Shows | Suggested caption |
|------|-------|-------------------|
| `01-home.png` | Home / Play | — |
| `02-onboarding.png` | First-run onboarding | "Roll each ring to find its opening." |
| `03-level-select.png` | Level grid | — |
| `04-level-1-anchor-tutorial.png` | L1 anchor + clip tutorial | "Full anchor rings never move." |
| `05-level-1-gap-clears-clip.png` | Gap aligned, ready glow | "Line the gap up, then pull it free." |
| `06-blocked-clip-feedback.png` | Blocked pull, blocker flash | "Small clips show where rings are caught." |
| `07-level-10-interlocks.png` | Mid-game interlocks | "Clear the blockers in order." |
| `08-level-20-final-knot.png` | Dense final knot | "Free the copper knot to finish." |
| `09-level-complete-anchors-remain.png` | Completion overlay | "20 hand-built levels." |
| `10-settings.png` | Settings | — |

## App Store device sizes (owner to export)
Apple currently requires at least one set; provide the 6.7"/6.9" iPhone size and let
the rest scale, or capture per class:
- [ ] 6.9" (iPhone 16/17 Pro Max class)
- [ ] 6.7" (iPhone 15/16 Plus class) — optional if 6.9" provided
- [ ] 6.5" (legacy) — optional
- [ ] 5.5" (legacy) — only if supporting older devices
- [ ] 12.9"/13" iPad — only if the app is offered on iPad

## Notes
- All stills are genuine captures (no mock-ups, no copied reference art).
- Recommended order for the store: 05 → 06 → 04 → 08 → 02 (lead with the core
  rotate-align-pull and the knot), owner's discretion.
- A short demo `.mov` was **not** captured — the simulator's headless `SimRenderServer`
  fails with `SimRenderServer.SimulatorError Code=2` on this host (see
  known-limitations-v1.md). Capture on a host with a stable render server or screen-
  record a real device.
