# Privacy — Ring Knot: Untangle Puzzle

Ring Knot is a fully offline, single-player puzzle game. It collects **no
personal data** and contains **no tracking**.

## What the app does NOT do

- ❌ No analytics SDKs
- ❌ No advertising or ad SDKs
- ❌ No Firebase or third-party backends
- ❌ No network calls of any kind
- ❌ No user accounts or sign-in
- ❌ No in-app purchases
- ❌ No data collection or sharing
- ❌ No device tracking; `NSPrivacyTracking` is `false` and the tracking-domains
  list is empty

## What the app does store (locally only)

The app persists a small amount of state on-device with `UserDefaults`:

- Level progress: unlocked level, completed levels, best move counts
- Settings: sound on/off, haptics on/off
- First-session flags: onboarding completed, Level 1 tutorial completed

None of this leaves the device. "Reset progress" in Settings clears it.

## Privacy manifest

`ios/RingKnot/RingKnot/Resources/PrivacyInfo.xcprivacy` declares:

| Field | Value |
| --- | --- |
| `NSPrivacyTracking` | `false` |
| `NSPrivacyTrackingDomains` | empty |
| `NSPrivacyCollectedDataTypes` | empty (no data collected) |
| `NSPrivacyAccessedAPITypes` | `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` |

`CA92.1` is Apple's approved reason: "Access info from same app, to read/write
to user defaults the app itself wrote." This matches our usage exactly.

## Required-reason API audit

A source scan (`grep` for the Apple required-reason API categories) found only
`UserDefaults` in use (in `Preferences.swift` and `Engine/ProgressStore.swift`).
No file-timestamp, system-boot-time, disk-space, or active-keyboard APIs are
used, so no other manifest entries are required. Re-run the audit with:

```bash
grep -rEn "UserDefaults|systemUptime|contentModificationDate|statfs|volumeAvailableCapacity|activeInputModes|mach_absolute_time" ios/RingKnot/RingKnot --include="*.swift"
```

If any new required-reason API is introduced, either remove it or add the
matching entry to `PrivacyInfo.xcprivacy` and update this document.
