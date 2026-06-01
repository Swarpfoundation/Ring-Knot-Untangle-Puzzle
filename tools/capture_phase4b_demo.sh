#!/usr/bin/env bash
#
# Capture a genuine simulator screen recording of the Phase 4B rotate-then-pull
# demo: unaligned gap → rotate → ready → real pull-release → completion.
#
# It boots the chosen simulator, starts `simctl io recordVideo`, runs the
# scripted UI walkthrough (ScreenshotTour/test_phase4bDemoWalkthrough) on that
# same device, then stops the recording so the .mov is finalized.
#
#   bash tools/capture_phase4b_demo.sh
#
# Output: docs/screenshots/phase-4b-rotation-demo.mov

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
PROJECT="ios/RingKnot/RingKnot.xcodeproj"
OUT="docs/screenshots/phase-4b-rotation-demo.mov"

UDID="$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
[ -n "$UDID" ] || { echo "No available simulator named '$SIM_NAME'"; exit 1; }
echo "Using simulator $SIM_NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b || true

rm -f "$OUT"
echo "Starting screen recording -> $OUT"
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT" &
REC_PID=$!

cleanup() {
  echo "Stopping recording (pid $REC_PID)"
  kill -INT "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Give the recorder a moment to spin up.
sleep 2

echo "Running demo walkthrough UI test"
xcodebuild -project "$PROJECT" -scheme RingKnot \
  -destination "id=$UDID" -configuration Debug test \
  -only-testing:RingKnotUITests/ScreenshotTour/test_phase4bDemoWalkthrough \
  >/tmp/phase4b_demo.log 2>&1 || { echo "demo test failed; see /tmp/phase4b_demo.log"; tail -20 /tmp/phase4b_demo.log; exit 1; }

# Let the final completion frame land before we stop the recorder.
sleep 1
cleanup
trap - EXIT

if [ -f "$OUT" ]; then
  echo "Recorded $(du -h "$OUT" | cut -f1) -> $OUT"
else
  echo "Recording file not produced"; exit 1
fi
