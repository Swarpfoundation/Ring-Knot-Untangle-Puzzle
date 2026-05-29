#!/usr/bin/env bash
#
# Local CI for Ring Knot iOS. Fails fast with a clear message on the first
# broken step. Run from anywhere; paths are resolved relative to the repo root.
#
#   bash tools/ci_local.sh
#
# Optional: override the simulator destination.
#   SIM_DEST='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' bash tools/ci_local.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SIM_DEST="${SIM_DEST:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
PROJECT="ios/RingKnot/RingKnot.xcodeproj"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31mCI FAILED: %s\033[0m\n' "$1" >&2; exit 1; }

# Run a command, capturing output. On success print a short summary; on failure
# dump the tail of the log and abort.
run_logged() {
  local desc="$1"; shift
  local log; log="$(mktemp)"
  if "$@" >"$log" 2>&1; then
    grep -E "BUILD SUCCEEDED|TEST SUCCEEDED|Executed .* test" "$log" | tail -4 || true
  else
    echo "---- last 40 lines: $desc ----" >&2
    tail -40 "$log" >&2
    fail "$desc"
  fi
}

step "1/6  Verify generated assets"
bash tools/verify_assets.sh || fail "asset verification failed"

step "2/6  Replay validator (self-test + level pack)"
python3 tools/replay_validator.py --selftest || fail "replay validator self-test failed"
python3 tools/replay_validator.py || fail "level pack replay failed"

step "3/6  Regenerate Xcode project"
( cd ios/RingKnot && xcodegen generate ) || fail "xcodegen generate failed"

step "4/6  Debug build"
run_logged "Debug build" xcodebuild -project "$PROJECT" -scheme RingKnot \
  -destination "$SIM_DEST" -configuration Debug build

step "5/6  Debug test (unit + UI)"
run_logged "Debug test" xcodebuild -project "$PROJECT" -scheme RingKnot \
  -destination "$SIM_DEST" -configuration Debug test

step "6/6  Release build (confirms DEBUG bridge excluded)"
run_logged "Release build" xcodebuild -project "$PROJECT" -scheme RingKnot \
  -destination "$SIM_DEST" -configuration Release build

printf '\n\033[1;32mCI PASSED\033[0m\n'
