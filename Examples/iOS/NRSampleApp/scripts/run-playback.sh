#!/usr/bin/env bash
#
# run-playback.sh — automation for the NRSampleApp catalog.
#
# Builds the app, boots a simulator, and plays each catalog item:
#   - VOD scenarios run to natural end (wait for "Player didPlayToEnd"
#     in the per-scenario log file). Capped at 15 minutes for safety.
#   - Live scenarios run for a configured wall-clock duration.
#
# This is REAL playback — AVKit's `VideoPlayer` decodes and renders the
# stream in the simulator. The simulator window stays focused so a human
# can watch / hear it. A mid-playback screenshot is captured per scenario
# as artifact proof of actual rendering.
#
# Designed to run identically on a developer's laptop and on GitHub Actions.
#
# Usage:
#   ./scripts/run-playback.sh
#   SCENARIOS=bipbop-adv,akamai-live ./scripts/run-playback.sh   # subset
#
# Environment overrides:
#   DEVICE_NAME       Simulator to use (default: "iPhone 16 Pro")
#   ARTIFACTS_DIR     Where to write artifacts (default: build/playback-artifacts)
#   DERIVED_DATA      DerivedData path (default: build)
#

set -euo pipefail

# Run from the NRSampleApp directory regardless of where this is invoked.
cd "$(dirname "$0")/.."

DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
APP_BUNDLE_ID="com.newrelic.video.sample.NRSampleApp"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-build/playback-artifacts}"
DERIVED_DATA="${DERIVED_DATA:-build}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/NRSampleApp.app"

# VOD safety cap: if "didPlayToEnd" never fires, stop after this long.
VOD_MAX_WAIT_SECS=900

# Default scenarios — id:mode where mode is "vod" or "live=<seconds>".
# Order: cheap VODs first (fast feedback), then live (longest).
DEFAULT_SCENARIOS=(
  "bipbop-adv:vod"
  "bipbop-basic:vod"
  "big-buck-bunny:vod"
  "akamai-live:live=1800"
)

# Optional subset via SCENARIOS=foo,bar
if [ -n "${SCENARIOS:-}" ]; then
  IFS=',' read -ra SELECTED <<< "$SCENARIOS"
  declare -a RUN_LIST=()
  for sel in "${SELECTED[@]}"; do
    found=0
    for s in "${DEFAULT_SCENARIOS[@]}"; do
      if [[ "$s" == "$sel:"* ]]; then
        RUN_LIST+=("$s")
        found=1
        break
      fi
    done
    [ $found -eq 0 ] && echo "WARN: scenario '$sel' not found — ignored"
  done
  [ ${#RUN_LIST[@]} -eq 0 ] && { echo "ERROR: SCENARIOS filter matched nothing"; exit 1; }
else
  RUN_LIST=("${DEFAULT_SCENARIOS[@]}")
fi

mkdir -p "$ARTIFACTS_DIR"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Resolving simulator: $DEVICE_NAME"
DEVICE_LINE=$(xcrun simctl list devices "$DEVICE_NAME" available | grep -m1 "$DEVICE_NAME" || true)
if [ -z "$DEVICE_LINE" ]; then
  echo "ERROR: no simulator named '$DEVICE_NAME' available"
  echo "Available:"
  xcrun simctl list devices available
  exit 1
fi
DEVICE_ID=$(echo "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
echo "    $DEVICE_ID"

echo "==> Booting simulator (no-op if already booted)"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
# Bring the simulator window forward so a human can watch playback.
open -a Simulator || true

echo "==> Building NRSampleApp"
xcodebuild build \
  -project NRSampleApp.xcodeproj \
  -scheme NRSampleApp \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  > "$ARTIFACTS_DIR/build.log" 2>&1
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: build did not produce $APP_PATH"
  tail -40 "$ARTIFACTS_DIR/build.log"
  exit 1
fi
echo "    built: $APP_PATH"

echo "==> Installing app"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

# Per-scenario summary
SUMMARY="$ARTIFACTS_DIR/SUMMARY.txt"
{
  echo "Playback run: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Device:       $DEVICE_NAME ($DEVICE_ID)"
  echo "Scenarios:    ${#RUN_LIST[@]}"
  echo ""
  printf "%-20s %-14s %-10s %-8s %-7s %-10s\n" "id" "mode" "elapsed" "events" "fails" "result"
  printf "%-20s %-14s %-10s %-8s %-7s %-10s\n" "----" "----" "-------" "------" "-----" "------"
} > "$SUMMARY"

OVERALL_RC=0

run_one_scenario() {
  local ID="$1"
  local MODE="$2"

  local MAX_WAIT
  local END_MODE
  if [[ "$MODE" == "vod" ]]; then
    MAX_WAIT=$VOD_MAX_WAIT_SECS
    END_MODE="end"
  elif [[ "$MODE" == live=* ]]; then
    MAX_WAIT="${MODE#live=}"
    END_MODE="time"
  else
    echo "    ERROR: unknown mode '$MODE'"
    return 2
  fi

  echo ""
  echo "==> $ID  (mode=$END_MODE, cap=${MAX_WAIT}s)"

  # Make sure no stale instance is running.
  xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
  sleep 1

  # Launch the app with the auto-play arg. The app's RootView picks up the
  # arg, redirects logs to auto-play-<ID>.log (truncated), navigates to the
  # player view, and starts real playback.
  xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID" --auto-play "$ID" > /dev/null
  echo "    launched · video should now be rendering in the simulator"

  # Find the log file inside the app's data container.
  CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "$APP_BUNDLE_ID" data 2>/dev/null || true)
  local LOG_FILE="$CONTAINER/Documents/logs/auto-play-$ID.log"

  # Mid-playback screenshot: capture at 30s in (or 25% through, whichever sooner).
  local SHOT_AT=$(( MAX_WAIT < 120 ? MAX_WAIT / 4 : 30 ))
  ( sleep "$SHOT_AT" && xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS_DIR/$ID-screenshot.png" 2>/dev/null ) &
  local SHOT_PID=$!

  # Wait loop.
  local ELAPSED=0
  local NATURAL_END=0
  while [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))

    if [ "$END_MODE" = "end" ] && [ -f "$LOG_FILE" ]; then
      if grep -q "Player didPlayToEnd" "$LOG_FILE" 2>/dev/null; then
        NATURAL_END=1
        echo "    didPlayToEnd at ${ELAPSED}s — natural end"
        break
      fi
      if grep -q "\[FAIL " "$LOG_FILE" 2>/dev/null; then
        echo "    early failure detected at ${ELAPSED}s"
        break
      fi
    fi

    if [ $((ELAPSED % 60)) -eq 0 ]; then
      echo "    still playing... ${ELAPSED}s elapsed"
    fi
  done

  # Make sure screenshot finished.
  wait $SHOT_PID 2>/dev/null || true

  # Stop the app cleanly.
  xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" 2>/dev/null || true

  # Copy logs to artifacts.
  local DEST="$ARTIFACTS_DIR/$ID"
  mkdir -p "$DEST"
  if [ -n "${CONTAINER:-}" ] && [ -d "$CONTAINER/Documents/logs" ]; then
    cp -R "$CONTAINER/Documents/logs/." "$DEST/" 2>/dev/null || true
  fi

  # Summarize.
  local EVENT_COUNT=0
  local FAIL_COUNT=0
  local SCENARIO_LOG="$DEST/auto-play-$ID.log"
  if [ -f "$SCENARIO_LOG" ]; then
    EVENT_COUNT=$(grep -c "\[EVENT" "$SCENARIO_LOG" || true)
    FAIL_COUNT=$(grep -c "\[FAIL"  "$SCENARIO_LOG" || true)
  fi

  local RESULT
  if [ "$FAIL_COUNT" -gt 0 ]; then
    RESULT="fail"
  elif [ "$END_MODE" = "end" ] && [ "$NATURAL_END" -eq 0 ]; then
    RESULT="timeout"
  else
    RESULT="ok"
  fi

  echo "    result=$RESULT  events=$EVENT_COUNT  fails=$FAIL_COUNT"
  printf "%-20s %-14s %-10s %-8s %-7s %-10s\n" \
    "$ID" "$MODE" "${ELAPSED}s" "$EVENT_COUNT" "$FAIL_COUNT" "$RESULT" >> "$SUMMARY"

  [ "$RESULT" = "ok" ] || return 1
}

for entry in "${RUN_LIST[@]}"; do
  ID="${entry%%:*}"
  MODE="${entry#*:}"
  run_one_scenario "$ID" "$MODE" || OVERALL_RC=1
done

echo ""
echo "============================================================"
cat "$SUMMARY"
echo "============================================================"
echo "Artifacts in: $ARTIFACTS_DIR"
echo "  - per-scenario logs:        <id>/auto-play-<id>.log"
echo "  - mid-playback screenshots: <id>-screenshot.png"
echo "  - run summary:              SUMMARY.txt"
exit $OVERALL_RC
