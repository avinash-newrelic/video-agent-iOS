#!/usr/bin/env bash
#
# run-playback.sh — automation for the NRSampleApp catalog.
#
# Builds the app, boots a simulator, and plays each catalog item for a
# fixed wall-clock duration declared per scenario. Durations are explicit
# because Apple's HLS reference streams (BipBop) are 30+ minutes long —
# "play to natural end" makes daily runs absurd.
#
# This is REAL playback — AVKit's `VideoPlayer` decodes and renders the
# stream in the simulator. The simulator window stays focused so a human
# can watch / hear it. A mid-playback screenshot is captured per scenario
# as artifact proof of actual rendering.
#
# Designed to run identically on a developer's laptop and on GitHub Actions.
#
# Usage:
#   ./scripts/run-playback.sh                                                  # iOS, default device
#   PLATFORM=tvOS ./scripts/run-playback.sh                                    # tvOS
#   PLATFORM=iOS DEVICE_NAME='iPhone 15' OS_VERSION=17.5 ./scripts/run-playback.sh
#   SCENARIOS=bipbop-adv,akamai-live ./scripts/run-playback.sh                 # subset
#
# Environment overrides:
#   PLATFORM          'iOS' (default) or 'tvOS'
#   DEVICE_NAME       Simulator name (default: "iPhone 16 Pro" for iOS,
#                     "Apple TV 4K (3rd generation)" for tvOS)
#   OS_VERSION        Simulator OS version (default: latest available)
#   SCHEME            Xcode scheme (default: NRSampleApp_<platform>)
#   ARTIFACTS_DIR     Where to write artifacts (default: build/playback-artifacts)
#   DERIVED_DATA      DerivedData path (default: build)
#

set -euo pipefail

# Run from the NRSampleApp directory regardless of where this is invoked.
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iOS}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-build/playback-artifacts}"
DERIVED_DATA="${DERIVED_DATA:-build}"

case "$PLATFORM" in
  iOS)
    DESTINATION_PLATFORM="iOS Simulator"
    BUILD_PRODUCTS_DIR="Debug-iphonesimulator"
    DEFAULT_DEVICE="iPhone 16 Pro"
    APP_BUNDLE_ID="com.newrelic.video.sample.NRSampleApp"
    DEFAULT_SCHEME="NRSampleApp_iOS"
    ;;
  tvOS)
    DESTINATION_PLATFORM="tvOS Simulator"
    BUILD_PRODUCTS_DIR="Debug-appletvsimulator"
    DEFAULT_DEVICE="Apple TV 4K (3rd generation)"
    APP_BUNDLE_ID="com.newrelic.video.sample.NRSampleApp.tvOS"
    DEFAULT_SCHEME="NRSampleApp_tvOS"
    ;;
  *)
    echo "ERROR: PLATFORM must be 'iOS' or 'tvOS' (got: $PLATFORM)"
    exit 1
    ;;
esac

DEVICE_NAME="${DEVICE_NAME:-$DEFAULT_DEVICE}"
SCHEME="${SCHEME:-$DEFAULT_SCHEME}"
OS_VERSION="${OS_VERSION:-}"
APP_PATH="$DERIVED_DATA/Build/Products/$BUILD_PRODUCTS_DIR/NRSampleApp.app"

# Default scenarios — id:duration_secs.
# Each video plays for that many seconds of REAL playback then is killed.
# Tune per-scenario as needed. Apple BipBop streams are ~30 min total;
# 60s of real playback is plenty to verify decode+render+no-error.
# Order: cheap VODs first (fast feedback), then live (longest).
DEFAULT_SCENARIOS=(
  "bipbop-adv:60"
  "bipbop-basic:60"
  "big-buck-bunny:60"
  "akamai-live:1800"
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

echo "==> Resolving simulator: $DEVICE_NAME ($PLATFORM${OS_VERSION:+, OS=$OS_VERSION})"
DEVICE_LINE=$(xcrun simctl list devices "$DEVICE_NAME" available | grep -m1 "$DEVICE_NAME" || true)
if [ -z "$DEVICE_LINE" ]; then
  echo "ERROR: no simulator named '$DEVICE_NAME' available"
  echo "Available:"
  xcrun simctl list devices available
  exit 1
fi
DEVICE_ID=$(echo "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
echo "    $DEVICE_ID"

# xcodebuild destination string
if [ -n "$OS_VERSION" ]; then
  DESTINATION="platform=$DESTINATION_PLATFORM,name=$DEVICE_NAME,OS=$OS_VERSION"
else
  DESTINATION="platform=$DESTINATION_PLATFORM,name=$DEVICE_NAME"
fi

echo "==> Booting simulator (no-op if already booted)"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
# Bring the simulator window forward so a human can watch playback.
open -a Simulator || true

echo "==> Building $SCHEME"
xcodebuild build \
  -project NRSampleApp.xcodeproj \
  -scheme "$SCHEME" \
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
  echo "Platform:     $PLATFORM"
  echo "Scheme:       $SCHEME"
  echo "Device:       $DEVICE_NAME ($DEVICE_ID)"
  echo "OS:           ${OS_VERSION:-(default)}"
  echo "Scenarios:    ${#RUN_LIST[@]}"
  echo ""
  printf "%-20s %-10s %-8s %-7s %-10s\n" "id" "duration" "events" "fails" "result"
  printf "%-20s %-10s %-8s %-7s %-10s\n" "----" "--------" "------" "-----" "------"
} > "$SUMMARY"

OVERALL_RC=0

run_one_scenario() {
  local ID="$1"
  local DURATION="$2"

  echo ""
  echo "==> $ID  (duration=${DURATION}s)"

  # Make sure no stale instance is running.
  xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
  sleep 1

  # Bring the simulator to the front so its GPU keeps rendering frames
  # (iOS Simulator pauses video render when its window is occluded).
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true

  # Launch the app with the auto-play arg. RootView picks up the arg,
  # redirects logs to auto-play-<ID>.log (truncated), navigates to the
  # player, and starts real playback.
  xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID" --auto-play "$ID" > /dev/null
  echo "    launched · video rendering in simulator for ${DURATION}s"

  # Find the log file inside the app's data container.
  CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "$APP_BUNDLE_ID" data 2>/dev/null || true)
  local LOG_FILE="$CONTAINER/Documents/logs/auto-play-$ID.log"

  # Mid-playback screenshot: capture at 25% through (or 30s, whichever sooner).
  local SHOT_AT=$(( DURATION < 120 ? DURATION / 4 : 30 ))
  ( sleep "$SHOT_AT" && xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS_DIR/$ID-screenshot.png" 2>/dev/null ) &
  local SHOT_PID=$!

  # Sleep the duration. Print progress every 60s for long runs.
  local ELAPSED=0
  while [ $ELAPSED -lt $DURATION ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))

    # Early-exit on FAIL events — no need to wait the full duration.
    if [ -f "$LOG_FILE" ] && grep -q "\[FAIL " "$LOG_FILE" 2>/dev/null; then
      echo "    [FAIL] event detected at ${ELAPSED}s — stopping early"
      break
    fi

    if [ $((ELAPSED % 60)) -eq 0 ]; then
      echo "    still playing... ${ELAPSED}s / ${DURATION}s"
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
  else
    RESULT="ok"
  fi

  echo "    result=$RESULT  events=$EVENT_COUNT  fails=$FAIL_COUNT"
  printf "%-20s %-10s %-8s %-7s %-10s\n" \
    "$ID" "${DURATION}s" "$EVENT_COUNT" "$FAIL_COUNT" "$RESULT" >> "$SUMMARY"

  [ "$RESULT" = "ok" ] || return 1
}

for entry in "${RUN_LIST[@]}"; do
  ID="${entry%%:*}"
  DURATION="${entry##*:}"
  run_one_scenario "$ID" "$DURATION" || OVERALL_RC=1
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
