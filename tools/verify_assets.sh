#!/usr/bin/env bash
# verify_assets.sh
# Validates that every required Ring Knot asset exists with the expected
# format. Fails fast with a clear, single-line error message.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/shared/assets"

PASS=0
FAIL=0

fail() {
    echo "FAIL  $1"
    FAIL=$((FAIL + 1))
}

pass() {
    echo "OK    $1"
    PASS=$((PASS + 1))
}

require_png() {
    local rel="$1"
    local expected_w="$2"
    local expected_h="$3"
    local expected_alpha="$4"   # yes | no | any
    local path="$ASSETS/$rel"
    if [[ ! -f "$path" ]]; then
        fail "$rel  (missing file)"
        return
    fi
    if ! sips_out=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$path" 2>/dev/null); then
        fail "$rel  (sips failed)"
        return
    fi
    local w
    local h
    local alpha
    w=$(echo "$sips_out" | awk -F': ' '/pixelWidth/ {print $2}' | tr -d ' ')
    h=$(echo "$sips_out" | awk -F': ' '/pixelHeight/ {print $2}' | tr -d ' ')
    alpha=$(echo "$sips_out" | awk -F': ' '/hasAlpha/ {print $2}' | tr -d ' ')
    if [[ "$w" != "$expected_w" || "$h" != "$expected_h" ]]; then
        fail "$rel  size ${w}x${h} expected ${expected_w}x${expected_h}"
        return
    fi
    if [[ "$expected_alpha" != "any" && "$alpha" != "$expected_alpha" ]]; then
        fail "$rel  alpha=$alpha expected $expected_alpha"
        return
    fi
    pass "$rel  ${w}x${h} alpha=$alpha"
}

require_wav() {
    local rel="$1"
    local path="$ASSETS/$rel"
    if [[ ! -f "$path" ]]; then
        fail "$rel  (missing file)"
        return
    fi
    local size
    size=$(stat -f%z "$path" 2>/dev/null || echo 0)
    if [[ "$size" -lt 1000 ]]; then
        fail "$rel  too small ($size bytes)"
        return
    fi
    # Quick RIFF/WAVE magic check
    if ! head -c 4 "$path" | grep -q "RIFF"; then
        fail "$rel  not RIFF"
        return
    fi
    pass "$rel  ${size} bytes RIFF"
}

# --- Branding ---
require_png "branding/ring_knot_app_icon_master.png"        1024 1024 no
require_png "branding/ring_knot_brand_mark.png"             2048 2048 yes
require_png "branding/ring_knot_home_hero.png"              2048 2048 yes
require_png "branding/ring_knot_level_complete_emblem.png"  1024 1024 yes

# --- Materials ---
require_png "materials/material_brushed_silver_tile.png"    1024 1024 no
require_png "materials/material_brushed_copper_tile.png"    1024 1024 no
require_png "materials/material_dark_obsidian_tile.png"     1024 1024 no
require_png "materials/material_connector_clip_silver.png"   512  512 yes
require_png "materials/material_connector_clip_copper.png"   512  512 yes

# --- Backgrounds ---
require_png "backgrounds/bg_gameplay_obsidian_portrait.png" 2048 3072 no
require_png "backgrounds/bg_menu_obsidian_portrait.png"     2048 3072 no
require_png "backgrounds/bg_completion_dark_burst.png"      2048 3072 no

# --- FX ---
require_png "fx/fx_ring_selection_glow.png"  1024 1024 yes
require_png "fx/fx_ring_release_streak.png"  1024  512 yes
require_png "fx/fx_metal_spark.png"           512  512 yes
require_png "fx/fx_invalid_shockwave.png"    1024 1024 yes

# --- UI ---
require_png "ui/ui_drag_arrow_master.png"  512 512 yes
require_png "ui/ui_hint_pulse.png"         512 512 yes
require_png "ui/ui_button_restart.png"     512 512 yes
require_png "ui/ui_button_back.png"        512 512 yes
require_png "ui/ui_button_next.png"        512 512 yes
require_png "ui/ui_button_hint.png"        512 512 yes

# --- SFX ---
require_wav "sfx/sfx_ring_select.wav"
require_wav "sfx/sfx_ring_drag_soft.wav"
require_wav "sfx/sfx_ring_invalid.wav"
require_wav "sfx/sfx_ring_release.wav"
require_wav "sfx/sfx_hint.wav"
require_wav "sfx/sfx_level_complete.wav"
require_wav "sfx/sfx_button_tap.wav"

echo ""
echo "Verified: $PASS passed, $FAIL failed."
if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
