# TestFlight / App Store — Owner-Needed Checklist (Ring Knot v1.0.0)

Everything below requires the **owner's** Apple Developer account and decisions.
None of these values are invented here — fill them in with the real values. The
codebase + RC package are ready; these are the human/account gates.

## Apple Developer account & signing
- [ ] **Apple Developer Team ID**: `__________` (owner to provide)
- [ ] Signing certificate (Apple Distribution) created in the team.
- [ ] Provisioning profile for `com.swarpfoundation.ringknot` (App Store).
- [ ] In Xcode / `project.yml`, set `DEVELOPMENT_TEAM` to the real Team ID and enable
      automatic or manual signing for the Release archive. *(Currently
      `DEVELOPMENT_TEAM` is empty and signing is simulator-only — do not hack this;
      the owner configures it.)*

## App Store Connect
- [ ] Create the **App Store Connect app record**.
- [ ] **Bundle ID confirmation**: `com.swarpfoundation.ringknot` ✅ (matches the build).
- [ ] **App display name confirmation**: `Ring Knot` ✅ (matches the build).
- [ ] **App name (store)**: `Ring Knot` (verify availability in App Store Connect).
- [ ] **Support URL**: `__________` (owner to provide a real, reachable URL).
- [ ] **Marketing URL** (optional): `__________`.

## Privacy & compliance
- [ ] **Privacy questionnaire**: confirm "Data Not Collected" — the app has no
      analytics, ads, accounts, network calls, or tracking. `PrivacyInfo.xcprivacy`
      already declares no tracking and no collected data types.
- [ ] **Export compliance**: the app uses **no encryption beyond Apple's standard
      libraries**; `ITSAppUsesNonExemptEncryption = false` is already set. Confirm the
      "uses non-exempt encryption: No" answer at submission.
- [ ] **Age rating questionnaire**: complete it (expected 4+ — no objectionable
      content; verify each answer with the owner).

## Store listing (draft provided — owner to finalise)
- [ ] **Final description** — draft in `docs/release/app-store-metadata-draft.md`.
- [ ] **Final keywords** — draft in `docs/release/app-store-metadata-draft.md`.
- [ ] **Subtitle / promotional text** — draft provided.
- [ ] **What's New (v1.0)** — draft provided.
- [ ] **Final screenshots** at required device sizes — see
      `docs/release/final-screenshot-plan.md`; fresh simulator stills are in
      `docs/screenshots/final-ios-v1/` as the basis.

## Device QA
- [ ] **Physical-device QA signoff** — run `docs/release/physical-device-qa-checklist.md`
      on a real iPhone with a provisioning profile. Not yet possible here (no device
      connected / signing not configured).

## Build upload (do NOT do without explicit owner confirmation)
- [ ] Archive a signed Release build (`xcodebuild … archive`) once signing is set.
- [ ] Upload to TestFlight / App Store Connect **only after the owner explicitly
      confirms** and all of the above are complete.
