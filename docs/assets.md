# Ring Knot — Generated assets

All Ring Knot assets are generated locally by deterministic scripts. Nothing is
downloaded, nothing is sourced from third-party brands, and no AI image API is
called. This document is the catalogue.

## Originality rule

The reference screenshots informed the puzzle genre only. They are not the
production art. The procedural scripts in `tools/` are the legal record:
running them on a clean checkout yields the same files we ship, with no outside
inputs.

Do not commit downloaded images, ad-screenshot crops, or copyrighted glyphs to
this repository. If a future designer replaces a generated asset by hand, the
replacement file should sit alongside the same path under `shared/assets/` and
be documented here.

## Regenerating

```
# images
swift tools/generate_assets.swift

# audio
python3 tools/generate_sfx.py

# verification
bash tools/verify_assets.sh
```

The scripts require no network access. They emit pixel-identical output unless
their internal parameters or seeds change. macOS only (`sips` + CoreGraphics).

## Generated files

### Branding — `shared/assets/branding/`

| File | Size | Alpha | Use in iOS |
| --- | --- | --- | --- |
| `ring_knot_app_icon_master.png` | 1024×1024 | no | source for `AppIcon.appiconset` |
| `ring_knot_brand_mark.png` | 2048×2048 | yes | compact mark in HUD / loaders |
| `ring_knot_home_hero.png` | 2048×2048 | yes | hero illustration on `HomeView` |
| `ring_knot_level_complete_emblem.png` | 1024×1024 | yes | emblem on completion overlay |

### Materials — `shared/assets/materials/`

| File | Size | Alpha | Use in iOS |
| --- | --- | --- | --- |
| `material_brushed_silver_tile.png` | 1024×1024 | no | optional subtle texture for silver rings |
| `material_brushed_copper_tile.png` | 1024×1024 | no | optional subtle texture for copper rings |
| `material_dark_obsidian_tile.png` | 1024×1024 | no | board background overlay |
| `material_connector_clip_silver.png` | 512×512 | yes | reserved for future connector rendering |
| `material_connector_clip_copper.png` | 512×512 | yes | reserved for future connector rendering |

### Backgrounds — `shared/assets/backgrounds/`

| File | Size | Alpha | Use in iOS |
| --- | --- | --- | --- |
| `bg_menu_obsidian_portrait.png` | 2048×3072 | no | `HomeView` and `LevelSelectView` background |
| `bg_gameplay_obsidian_portrait.png` | 2048×3072 | no | `GameView` / `GameScene` background |
| `bg_completion_dark_burst.png` | 2048×3072 | no | completion overlay background |

### FX — `shared/assets/fx/`

| File | Size | Alpha | Use in iOS |
| --- | --- | --- | --- |
| `fx_ring_selection_glow.png` | 1024×1024 | yes | sprite under selected ring |
| `fx_ring_release_streak.png` | 1024×512 | yes | motion streak during exit |
| `fx_metal_spark.png` | 512×512 | yes | `SKEmitterNode` particle on release |
| `fx_invalid_shockwave.png` | 1024×1024 | yes | shockwave on blocked move |

### UI — `shared/assets/ui/`

| File | Size | Alpha | Use in iOS |
| --- | --- | --- | --- |
| `ui_drag_arrow_master.png` | 512×512 | yes | hint arrow, rotated at runtime |
| `ui_hint_pulse.png` | 512×512 | yes | hint pulse overlay |
| `ui_button_restart.png` | 512×512 | yes | restart HUD button |
| `ui_button_back.png` | 512×512 | yes | navigation back button |
| `ui_button_next.png` | 512×512 | yes | next-level button on completion |
| `ui_button_hint.png` | 512×512 | yes | hint HUD button |

### SFX — `shared/assets/sfx/`

| File | Length | Use in iOS |
| --- | --- | --- |
| `sfx_button_tap.wav` | 0.08 s | menu and HUD button taps |
| `sfx_ring_select.wav` | 0.10 s | ring selection |
| `sfx_hint.wav` | 0.25 s | hint pulse |
| `sfx_ring_invalid.wav` | 0.25 s | blocked / wrong direction |
| `sfx_ring_drag_soft.wav` | 0.30 s | optional drag whisper (loaded but currently not played to avoid annoyance) |
| `sfx_ring_release.wav` | 0.45 s | successful ring exit |
| `sfx_level_complete.wav` | 1.20 s | level complete |

All WAVs are 44.1 kHz mono, 16-bit PCM, RIFF-headered, peak-limited to ~55 % of
full scale.

## iOS integration

- Source files for the asset catalog (`Assets.xcassets`) reference the PNGs by
  relative path through `XcodeGen` build rules.
- WAV files are added to the app target's resources so `AVAudioPlayer` can load
  them by short name.
- The asset catalog only contains references — the original PNGs live in
  `shared/assets/` so future Android builds can consume the same files.

## Replacing a generated asset by hand

1. Drop the replacement file at the same path under `shared/assets/...` (same
   filename, same dimensions, same alpha mode).
2. Re-run `bash tools/verify_assets.sh` to confirm it still matches the
   expected format.
3. Run `cd ios/RingKnot && xcodegen generate && xcodebuild build` to confirm
   the bundle picks it up cleanly.
4. Note the human source / licence in this file, replacing the procedural row.

The procedural generator does not need to change to support manual overrides —
the path is the contract.
