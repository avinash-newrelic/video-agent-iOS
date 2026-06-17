#!/usr/bin/env bash
#
# run-playback.sh — automation for the NRSampleApp catalog.
#
# Builds the app, boots a simulator, and plays every catalog item:
#   - VOD: plays to natural didPlayToEnd (capped at VOD_SAFETY_CAP secs)
#   - Live: plays for a configured wall-clock duration
#
# Real AVKit playback. Simulator window stays focused. Mid-playback
# screenshot per scenario. Per-scenario log file copied to artifacts.
#
# Usage:
#   ./scripts/run-playback.sh
#   PLATFORM=tvOS ./scripts/run-playback.sh
#   SCENARIOS=bipbop-basic ./scripts/run-playback.sh
#
# CI sets these inside each matrix leg:
#   PLATFORM, SCHEME, DEVICE_NAME, OS_VERSION, LEG_TAG
#
# All NRVA settings are forwarded to the simulator launchd as env vars,
# read by NewRelicSetup at app launch. Layered config (high → low):
#   1. NR_OVERRIDES_JSON (workflow_dispatch input)
#   2. NEW_RELIC_* env vars (GitHub vars.* / secrets.* in workflow)
#   3. playback-config.json per_leg block (matched by LEG_TAG)
#   4. playback-config.json global block
#   5. defaults below
#

set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Platform + simulator resolution ---------------------------------------

PLATFORM="${PLATFORM:-iOS}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-build/playback-artifacts}"
DERIVED_DATA="${DERIVED_DATA:-build}"
CONFIG_FILE="${CONFIG_FILE:-playback-config.json}"
LEG_TAG="${LEG_TAG:-}"

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
  *) echo "ERROR: PLATFORM must be 'iOS' or 'tvOS' (got: $PLATFORM)"; exit 1 ;;
esac

DEVICE_NAME="${DEVICE_NAME:-$DEFAULT_DEVICE}"
SCHEME="${SCHEME:-$DEFAULT_SCHEME}"
OS_VERSION="${OS_VERSION:-}"
APP_PATH="$DERIVED_DATA/Build/Products/$BUILD_PRODUCTS_DIR/NRSampleApp.app"

# ---- Layered NRVA config merge --------------------------------------------

# Layer 5: hard-coded defaults
NR_HARVEST=10
NR_LIVE_HARVEST=10
NR_REG_BATCH=65536
NR_LIVE_BATCH=32768
NR_DEAD_LETTER=100
NR_OFFLINE_MB=10
NR_QOE_ENABLED=true
NR_QOE_MULT=2
NR_DEBUG=true
NR_MEM_OPT=false
NR_COLLECTOR=""
NR_EXTRA_STREAMS=""

read_jq() {           # read_jq <path-expression> <var>
  local val
  val=$(jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null || true)
  [ -n "$val" ] && eval "$2=\"\$val\""
}

if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  echo "==> Reading $CONFIG_FILE"
  # Layer 4: global
  read_jq '.global.harvest_cycle_secs'        NR_HARVEST
  read_jq '.global.live_harvest_cycle_secs'   NR_LIVE_HARVEST
  read_jq '.global.regular_batch_size_bytes'  NR_REG_BATCH
  read_jq '.global.live_batch_size_bytes'     NR_LIVE_BATCH
  read_jq '.global.max_dead_letter_size'      NR_DEAD_LETTER
  read_jq '.global.max_offline_storage_mb'    NR_OFFLINE_MB
  read_jq '.global.qoe_enabled'               NR_QOE_ENABLED
  read_jq '.global.qoe_interval_multiplier'   NR_QOE_MULT
  read_jq '.global.debug_logging'             NR_DEBUG
  read_jq '.global.memory_optimization'       NR_MEM_OPT
  read_jq '.global.collector_address'         NR_COLLECTOR
  # Layer 3: per_leg
  if [ -n "$LEG_TAG" ]; then
    read_jq ".per_leg[\"$LEG_TAG\"].harvest_cycle_secs"        NR_HARVEST
    read_jq ".per_leg[\"$LEG_TAG\"].live_harvest_cycle_secs"   NR_LIVE_HARVEST
    read_jq ".per_leg[\"$LEG_TAG\"].regular_batch_size_bytes"  NR_REG_BATCH
    read_jq ".per_leg[\"$LEG_TAG\"].live_batch_size_bytes"     NR_LIVE_BATCH
    read_jq ".per_leg[\"$LEG_TAG\"].max_dead_letter_size"      NR_DEAD_LETTER
    read_jq ".per_leg[\"$LEG_TAG\"].max_offline_storage_mb"    NR_OFFLINE_MB
    read_jq ".per_leg[\"$LEG_TAG\"].qoe_enabled"               NR_QOE_ENABLED
    read_jq ".per_leg[\"$LEG_TAG\"].qoe_interval_multiplier"   NR_QOE_MULT
    read_jq ".per_leg[\"$LEG_TAG\"].debug_logging"             NR_DEBUG
    read_jq ".per_leg[\"$LEG_TAG\"].memory_optimization"       NR_MEM_OPT
    read_jq ".per_leg[\"$LEG_TAG\"].collector_address"         NR_COLLECTOR
  fi
fi

# Layer 2: env vars (set by GitHub vars.* / local exports)
[ -n "${NEW_RELIC_HARVEST_CYCLE_SECS:-}" ]       && NR_HARVEST="$NEW_RELIC_HARVEST_CYCLE_SECS"
[ -n "${NEW_RELIC_LIVE_HARVEST_CYCLE_SECS:-}" ]  && NR_LIVE_HARVEST="$NEW_RELIC_LIVE_HARVEST_CYCLE_SECS"
[ -n "${NEW_RELIC_REGULAR_BATCH_SIZE_BYTES:-}" ] && NR_REG_BATCH="$NEW_RELIC_REGULAR_BATCH_SIZE_BYTES"
[ -n "${NEW_RELIC_LIVE_BATCH_SIZE_BYTES:-}" ]    && NR_LIVE_BATCH="$NEW_RELIC_LIVE_BATCH_SIZE_BYTES"
[ -n "${NEW_RELIC_MAX_DEAD_LETTER_SIZE:-}" ]     && NR_DEAD_LETTER="$NEW_RELIC_MAX_DEAD_LETTER_SIZE"
[ -n "${NEW_RELIC_MAX_OFFLINE_STORAGE_MB:-}" ]   && NR_OFFLINE_MB="$NEW_RELIC_MAX_OFFLINE_STORAGE_MB"
[ -n "${NEW_RELIC_QOE_ENABLED:-}" ]              && NR_QOE_ENABLED="$NEW_RELIC_QOE_ENABLED"
[ -n "${NEW_RELIC_QOE_INTERVAL_MULTIPLIER:-}" ]  && NR_QOE_MULT="$NEW_RELIC_QOE_INTERVAL_MULTIPLIER"
[ -n "${NEW_RELIC_DEBUG_LOGGING:-}" ]            && NR_DEBUG="$NEW_RELIC_DEBUG_LOGGING"
[ -n "${NEW_RELIC_MEMORY_OPTIMIZATION:-}" ]      && NR_MEM_OPT="$NEW_RELIC_MEMORY_OPTIMIZATION"
[ -n "${NEW_RELIC_COLLECTOR_ADDRESS:-}" ]        && NR_COLLECTOR="$NEW_RELIC_COLLECTOR_ADDRESS"
[ -n "${PLAYBACK_EXTRA_STREAMS:-}" ]             && NR_EXTRA_STREAMS="$PLAYBACK_EXTRA_STREAMS"

# Layer 1: nr_overrides JSON from workflow_dispatch
if [ -n "${NR_OVERRIDES_JSON:-}" ] && [ "$NR_OVERRIDES_JSON" != "{}" ] && command -v jq >/dev/null 2>&1; then
  read_override() {
    local val
    val=$(echo "$NR_OVERRIDES_JSON" | jq -r ".$1 // empty" 2>/dev/null || true)
    [ -n "$val" ] && eval "$2=\"\$val\""
  }
  read_override harvest_cycle_secs        NR_HARVEST
  read_override live_harvest_cycle_secs   NR_LIVE_HARVEST
  read_override regular_batch_size_bytes  NR_REG_BATCH
  read_override live_batch_size_bytes     NR_LIVE_BATCH
  read_override max_dead_letter_size      NR_DEAD_LETTER
  read_override max_offline_storage_mb    NR_OFFLINE_MB
  read_override qoe_enabled               NR_QOE_ENABLED
  read_override qoe_interval_multiplier   NR_QOE_MULT
  read_override debug_logging             NR_DEBUG
  read_override memory_optimization       NR_MEM_OPT
  read_override collector_address         NR_COLLECTOR
fi

echo "==> NRVA config (resolved):"
echo "    harvest=${NR_HARVEST}s  liveHarvest=${NR_LIVE_HARVEST}s"
echo "    regBatch=${NR_REG_BATCH}B  liveBatch=${NR_LIVE_BATCH}B"
echo "    deadLetter=${NR_DEAD_LETTER}  offlineMB=${NR_OFFLINE_MB}"
echo "    qoe=${NR_QOE_ENABLED}×${NR_QOE_MULT}  debug=${NR_DEBUG}  memOpt=${NR_MEM_OPT}"
echo "    collector=${NR_COLLECTOR:-(default)}"
echo "    extraStreams=${NR_EXTRA_STREAMS:+(set, $(echo "$NR_EXTRA_STREAMS" | head -c 60)...)}"
echo "    extraStreams=${NR_EXTRA_STREAMS:-(none)}"

# ---- Scenarios -------------------------------------------------------------

VOD_SAFETY_CAP=3600
DEFAULT_SCENARIOS=(
  "bipbop-adv:end"
  "bipbop-basic:end"
  "big-buck-bunny:end"
  "akamai-live:fixed=1800"
)

if [ -n "${SCENARIOS:-}" ]; then
  IFS=',' read -ra SELECTED <<< "$SCENARIOS"
  declare -a RUN_LIST=()
  for sel in "${SELECTED[@]}"; do
    for s in "${DEFAULT_SCENARIOS[@]}"; do
      [[ "$s" == "$sel:"* ]] && RUN_LIST+=("$s")
    done
  done
  [ ${#RUN_LIST[@]} -eq 0 ] && { echo "ERROR: SCENARIOS filter matched nothing"; exit 1; }
else
  RUN_LIST=("${DEFAULT_SCENARIOS[@]}")
fi

mkdir -p "$ARTIFACTS_DIR"

# ---- Build -----------------------------------------------------------------

echo "==> xcodegen generate"
xcodegen generate

echo "==> Resolving simulator: $DEVICE_NAME ($PLATFORM${OS_VERSION:+, OS=$OS_VERSION})"
DEVICE_LINE=$(xcrun simctl list devices "$DEVICE_NAME" available | grep -m1 "$DEVICE_NAME" || true)
if [ -z "$DEVICE_LINE" ]; then
  echo "ERROR: no simulator named '$DEVICE_NAME' available"
  xcrun simctl list devices available
  exit 1
fi
DEVICE_ID=$(echo "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
echo "    $DEVICE_ID"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
open -a Simulator || true

echo "==> pod install"
pod install --repo-update > "$ARTIFACTS_DIR/pod-install.log" 2>&1 || {
  echo "pod install failed:"; tail -30 "$ARTIFACTS_DIR/pod-install.log"; exit 1;
}

echo "==> Building $SCHEME"
xcodebuild build \
  -workspace NRSampleApp.xcworkspace \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  > "$ARTIFACTS_DIR/build.log" 2>&1
[ -d "$APP_PATH" ] || { echo "ERROR: build did not produce $APP_PATH"; tail -40 "$ARTIFACTS_DIR/build.log"; exit 1; }

echo "==> Installing app"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

# ---- Summary header --------------------------------------------------------

SUMMARY="$ARTIFACTS_DIR/SUMMARY.txt"
{
  echo "Playback run: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Platform:     $PLATFORM"
  echo "Scheme:       $SCHEME"
  echo "Device:       $DEVICE_NAME ($DEVICE_ID)"
  echo "OS:           ${OS_VERSION:-(default)}"
  echo "Leg tag:      ${LEG_TAG:-(none)}"
  echo "Scenarios:    ${#RUN_LIST[@]}"
  echo "NR token:     ${NEW_RELIC_APP_TOKEN:+set}${NEW_RELIC_APP_TOKEN:-(not set)}"
  echo "Harvest:      ${NR_HARVEST}s / live ${NR_LIVE_HARVEST}s"
  echo "Debug log:    $NR_DEBUG"
  echo "Collector:    ${NR_COLLECTOR:-(default)}"
  echo ""
  printf "%-20s %-10s %-10s %-8s %-7s %-10s\n" "id" "mode" "elapsed" "events" "fails" "result"
  printf "%-20s %-10s %-10s %-8s %-7s %-10s\n" "----" "----" "-------" "------" "-----" "------"
} > "$SUMMARY"

OVERALL_RC=0

# ---- Per-scenario runner ---------------------------------------------------

run_one_scenario() {
  local ID="$1"
  local SPEC="$2"
  local MODE CAP_SECS

  case "$SPEC" in
    end)       MODE=end;   CAP_SECS=$VOD_SAFETY_CAP ;;
    end=*)     MODE=end;   CAP_SECS="${SPEC#end=}" ;;
    fixed=*)   MODE=fixed; CAP_SECS="${SPEC#fixed=}" ;;
    *) echo "    ERROR: unknown spec '$SPEC'"; return 2 ;;
  esac

  echo ""
  echo "==> $ID  (mode=$MODE  cap=${CAP_SECS}s)"

  xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" 2>/dev/null || true
  sleep 1
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true

  # Forward all NRVA + extra-streams env vars into the simulator's launchd.
  set_env() { [ -n "$2" ] && xcrun simctl spawn "$DEVICE_ID" launchctl setenv "$1" "$2" 2>/dev/null || true; }
  set_env NEW_RELIC_APP_TOKEN               "${NEW_RELIC_APP_TOKEN:-}"
  set_env NEW_RELIC_COLLECTOR_ADDRESS       "$NR_COLLECTOR"
  set_env NEW_RELIC_HARVEST_CYCLE_SECS      "$NR_HARVEST"
  set_env NEW_RELIC_LIVE_HARVEST_CYCLE_SECS "$NR_LIVE_HARVEST"
  set_env NEW_RELIC_REGULAR_BATCH_SIZE_BYTES "$NR_REG_BATCH"
  set_env NEW_RELIC_LIVE_BATCH_SIZE_BYTES   "$NR_LIVE_BATCH"
  set_env NEW_RELIC_MAX_DEAD_LETTER_SIZE    "$NR_DEAD_LETTER"
  set_env NEW_RELIC_MAX_OFFLINE_STORAGE_MB  "$NR_OFFLINE_MB"
  set_env NEW_RELIC_QOE_ENABLED             "$NR_QOE_ENABLED"
  set_env NEW_RELIC_QOE_INTERVAL_MULTIPLIER "$NR_QOE_MULT"
  set_env NEW_RELIC_DEBUG_LOGGING           "$NR_DEBUG"
  set_env NEW_RELIC_MEMORY_OPTIMIZATION     "$NR_MEM_OPT"
  set_env PLAYBACK_EXTRA_STREAMS            "$NR_EXTRA_STREAMS"

  xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID" --auto-play "$ID" > /dev/null
  echo "    launched · ${MODE} mode · cap ${CAP_SECS}s"

  CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "$APP_BUNDLE_ID" data 2>/dev/null || true)
  local LOG_FILE="$CONTAINER/Documents/logs/auto-play-$ID.log"

  local SHOT_AT=$(( CAP_SECS < 120 ? CAP_SECS / 4 : 30 ))
  ( sleep "$SHOT_AT" && xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS_DIR/$ID-screenshot.png" 2>/dev/null ) &
  local SHOT_PID=$!

  local ELAPSED=0
  local NATURAL_END=0
  while [ $ELAPSED -lt $CAP_SECS ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ -f "$LOG_FILE" ]; then
      if grep -q "\[FAIL " "$LOG_FILE" 2>/dev/null; then
        echo "    [FAIL] at ${ELAPSED}s — stopping"
        break
      fi
      if [ "$MODE" = "end" ] && grep -q "Player didPlayToEnd" "$LOG_FILE" 2>/dev/null; then
        NATURAL_END=1
        echo "    didPlayToEnd at ${ELAPSED}s"
        break
      fi
    fi
    [ $((ELAPSED % 60)) -eq 0 ] && echo "    still playing... ${ELAPSED}s / ${CAP_SECS}s"
  done

  wait $SHOT_PID 2>/dev/null || true
  xcrun simctl terminate "$DEVICE_ID" "$APP_BUNDLE_ID" 2>/dev/null || true

  local DEST="$ARTIFACTS_DIR/$ID"
  mkdir -p "$DEST"
  [ -d "$CONTAINER/Documents/logs" ] && cp -R "$CONTAINER/Documents/logs/." "$DEST/" 2>/dev/null || true

  local EVENT_COUNT=0
  local FAIL_COUNT=0
  local SCEN_LOG="$DEST/auto-play-$ID.log"
  if [ -f "$SCEN_LOG" ]; then
    EVENT_COUNT=$(grep -c "\[EVENT" "$SCEN_LOG" || true)
    FAIL_COUNT=$(grep -c  "\[FAIL"  "$SCEN_LOG" || true)
  fi

  local RESULT
  if [ "$FAIL_COUNT" -gt 0 ]; then
    RESULT="fail"
  elif [ "$MODE" = "end" ] && [ "$NATURAL_END" -eq 0 ]; then
    RESULT="cap-hit"
  else
    RESULT="ok"
  fi

  echo "    result=$RESULT  events=$EVENT_COUNT  fails=$FAIL_COUNT"
  printf "%-20s %-10s %-10s %-8s %-7s %-10s\n" \
    "$ID" "$MODE" "${ELAPSED}s" "$EVENT_COUNT" "$FAIL_COUNT" "$RESULT" >> "$SUMMARY"
  [ "$RESULT" = "ok" ] || return 1
}

for entry in "${RUN_LIST[@]}"; do
  ID="${entry%%:*}"
  SPEC="${entry#*:}"
  run_one_scenario "$ID" "$SPEC" || OVERALL_RC=1
done

echo ""
echo "============================================================"
cat "$SUMMARY"
echo "============================================================"
echo "Artifacts in: $ARTIFACTS_DIR"
exit $OVERALL_RC
