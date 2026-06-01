# TestFlight / App Store — owner-needed checklist

The engineering release candidate is complete and validated. The items below
**require an Apple Developer account and owner decisions** and cannot be filled in
from the codebase. None of these values are invented here — each is left blank for
the owner to supply.

## Signing & identifiers

| Item | Value (owner to fill) | Notes |
| --- | --- | --- |
| Apple Developer **Team ID** | `__________` | Set as `DEVELOPMENT_TEAM` in `ios/RingKnot/project.yml`, then `xcodegen generate`. |
| Signing certificate / provisioning | `__________` | Automatic signing recommended; or a manual distribution profile. |
| Bundle ID confirmation | `com.swarpfoundation.ringknot` | Already set in the project; confirm it matches the App Store Connect record. |
| App Store Connect app record | `__________` | Create the app with the bundle ID above. |

To enable a device / distribution build, set in `ios/RingKnot/project.yml`:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "<TEAM_ID>"
    CODE_SIGNING_ALLOWED: YES
    CODE_SIGNING_REQUIRED: YES
    CODE_SIGN_STYLE: Automatic
```

(The repo currently ships simulator-only: `DEVELOPMENT_TEAM` empty,
`CODE_SIGNING_ALLOWED: NO`.)

## Store presence

| Item | Value (owner to fill) |
| --- | --- |
| Support URL | `__________` |
| Marketing URL (optional) | `__________` |
| Final app description | see `app-store-metadata-draft.md` (review/approve) |
| Final keywords | see `app-store-metadata-draft.md` (review/approve) |
| Final screenshots (per device size) | from `docs/screenshots/final-ios/` (approve / re-shoot at required sizes) |
| Age rating questionnaire | `__________` (expected 4+ — no objectionable content; owner confirms) |

## Privacy & compliance

| Item | Status / owner action |
| --- | --- |
| App Privacy questionnaire | Answer **"Data Not Collected"**. The app has no analytics/ads/accounts/network; `PrivacyInfo.xcprivacy` declares no tracking, no collected data, `UserDefaults` required-reason `CA92.1`. |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` is set in Info.plist. Confirm the App Store Connect export-compliance answer: **does not use non-exempt encryption** (no custom crypto; only Apple standard libraries). |
| Encryption beyond Apple standard libraries | **No.** The app links only Apple system frameworks (verified by `otool -L`); no third-party crypto. |

## Upload (owner-confirmed only)

Do **not** upload until signing is configured and the owner explicitly confirms.
Once configured:

```bash
xcodebuild -scheme RingKnot -configuration Release \
  -archivePath build/RingKnot.xcarchive archive
# then distribute via Xcode Organizer or `xcrun altool` / `notarytool` as appropriate
```

This phase did **not** archive or upload (signing not configured).
