#!/usr/bin/env bash
# sync_xcassets.sh
# Builds ios/RingKnot/RingKnot/Resources/Assets.xcassets from the procedurally
# generated PNGs in shared/assets/. Pure bash + cp + cat. No third-party tools.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/shared/assets"
CATALOG="$ROOT/ios/RingKnot/RingKnot/Resources/Assets.xcassets"

if [[ ! -d "$ASSETS" ]]; then
    echo "Missing $ASSETS — run tools/generate_assets.swift first." >&2
    exit 1
fi

rm -rf "$CATALOG"
mkdir -p "$CATALOG"

# Root Contents.json
cat > "$CATALOG/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "ringknot-procedural",
    "version" : 1
  }
}
JSON

# AppIcon
mkdir -p "$CATALOG/AppIcon.appiconset"
cp "$ASSETS/branding/ring_knot_app_icon_master.png" "$CATALOG/AppIcon.appiconset/ring_knot_app_icon_master.png"
cat > "$CATALOG/AppIcon.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "ring_knot_app_icon_master.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "ringknot-procedural",
    "version" : 1
  }
}
JSON

# LaunchBackground — deep obsidian for the launch screen
mkdir -p "$CATALOG/LaunchBackground.colorset"
cat > "$CATALOG/LaunchBackground.colorset/Contents.json" <<'JSON'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.040",
          "green" : "0.025",
          "red" : "0.020"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "ringknot-procedural",
    "version" : 1
  }
}
JSON

# AccentColor — warm copper
mkdir -p "$CATALOG/AccentColor.colorset"
cat > "$CATALOG/AccentColor.colorset/Contents.json" <<'JSON'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.350",
          "green" : "0.550",
          "red" : "0.950"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "ringknot-procedural",
    "version" : 1
  }
}
JSON

write_imageset() {
    local name="$1"
    local src="$2"
    local dir="$CATALOG/${name}.imageset"
    mkdir -p "$dir"
    local base
    base=$(basename "$src")
    cp "$src" "$dir/$base"
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$base",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "ringknot-procedural",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : false,
    "template-rendering-intent" : "original"
  }
}
JSON
}

# Branding
write_imageset "ring_knot_brand_mark"            "$ASSETS/branding/ring_knot_brand_mark.png"
write_imageset "ring_knot_home_hero"             "$ASSETS/branding/ring_knot_home_hero.png"
write_imageset "ring_knot_level_complete_emblem" "$ASSETS/branding/ring_knot_level_complete_emblem.png"

# Backgrounds
write_imageset "bg_gameplay_obsidian_portrait" "$ASSETS/backgrounds/bg_gameplay_obsidian_portrait.png"
write_imageset "bg_menu_obsidian_portrait"     "$ASSETS/backgrounds/bg_menu_obsidian_portrait.png"
write_imageset "bg_completion_dark_burst"      "$ASSETS/backgrounds/bg_completion_dark_burst.png"

# FX
write_imageset "fx_ring_selection_glow" "$ASSETS/fx/fx_ring_selection_glow.png"
write_imageset "fx_ring_release_streak" "$ASSETS/fx/fx_ring_release_streak.png"
write_imageset "fx_metal_spark"         "$ASSETS/fx/fx_metal_spark.png"
write_imageset "fx_invalid_shockwave"   "$ASSETS/fx/fx_invalid_shockwave.png"

# UI
write_imageset "ui_drag_arrow_master" "$ASSETS/ui/ui_drag_arrow_master.png"
write_imageset "ui_hint_pulse"        "$ASSETS/ui/ui_hint_pulse.png"
write_imageset "ui_button_restart"    "$ASSETS/ui/ui_button_restart.png"
write_imageset "ui_button_back"       "$ASSETS/ui/ui_button_back.png"
write_imageset "ui_button_next"       "$ASSETS/ui/ui_button_next.png"
write_imageset "ui_button_hint"       "$ASSETS/ui/ui_button_hint.png"

# WAVs are NOT in the catalog — they ship as plain bundle resources via project.yml.

echo "Synced $CATALOG"
