# NRSampleApp — Runbook

iOS + tvOS video playback automation. Real AVKit playback. Per-scenario logs and screenshots. Optionally tracks via NewRelic when a token is set; otherwise plays videos without telemetry.

This app lives only on the `internal/video-rig` branch and is not merged to master.

---

## Quick start (local)

```bash
brew install xcodegen jq
cd Examples/iOS/NRSampleApp
./scripts/run-playback.sh                       # full run (~33-80 min)
SCENARIOS=bipbop-basic ./scripts/run-playback.sh   # one scenario
PLATFORM=tvOS ./scripts/run-playback.sh             # tvOS instead of iOS
```

The simulator stays focused so you can watch + hear playback. Artifacts land in `build/playback-artifacts/`.

---

## What runs by default

| Scenario | Stream | Mode | Duration |
|---|---|---|---|
| bipbop-adv | Apple HLS adaptive | play to natural end | ~10 min |
| bipbop-basic | Apple HLS basic | play to natural end | ~30 min |
| big-buck-bunny | Blender | play to natural end | ~10 min |
| akamai-live | Akamai HLS live | 30 min cap | 30 min |

VOD scenarios run until `didPlayToEnd` (capped at 60 min for safety). Live runs the full 30 min.

---

## NewRelic — optional

If `NEW_RELIC_APP_TOKEN` is **not** set, NRVA is silently disabled and the app still plays every video normally. Set the token to enable telemetry to the collector.

- Local: Xcode scheme → Arguments → Environment Variables, or `export NEW_RELIC_APP_TOKEN=...` before the script
- CI: GitHub repo → Settings → Secrets and variables → **Secrets** → `NEW_RELIC_APP_TOKEN`

### All 12 NRVA knobs (env-var driven)

| Variable | Default | Range / values |
|---|---|---|
| `NEW_RELIC_APP_TOKEN` | (none) | secret |
| `NEW_RELIC_COLLECTOR_ADDRESS` | (auto-detect prod) | `staging-mobile-collector.newrelic.com` etc. |
| `NEW_RELIC_HARVEST_CYCLE_SECS` | 10 | 5-300 |
| `NEW_RELIC_LIVE_HARVEST_CYCLE_SECS` | 10 | 1-60 |
| `NEW_RELIC_REGULAR_BATCH_SIZE_BYTES` | 65536 | 1024-1048576 |
| `NEW_RELIC_LIVE_BATCH_SIZE_BYTES` | 32768 | 512-524288 |
| `NEW_RELIC_MAX_DEAD_LETTER_SIZE` | 100 | 10-1000 |
| `NEW_RELIC_MAX_OFFLINE_STORAGE_MB` | 10 | ≥1 |
| `NEW_RELIC_QOE_ENABLED` | true | true / false |
| `NEW_RELIC_QOE_INTERVAL_MULTIPLIER` | 2 | ≥1 |
| `NEW_RELIC_DEBUG_LOGGING` | true | true / false |
| `NEW_RELIC_MEMORY_OPTIMIZATION` | false | true / false |

---

## Configuring without a PR

Layered config, priority high → low:

```
1. workflow_dispatch input (nr_overrides JSON, extra_streams JSON)
       │
       ▼
2. GitHub Actions Repository Variables   ← edit in UI, NO PR
   (Settings → Secrets and variables → Actions → Variables tab)
       │
       ▼
3. playback-config.json per_leg block    (committed, matrix-leg-specific)
       │
       ▼
4. playback-config.json global block     (committed, repo defaults)
       │
       ▼
5. NewRelicSetup.swift defaults          (code-level fallback)
```

| Want to | Do this |
|---|---|
| Always run all scenarios in staging | UI → Variables → set `NEW_RELIC_COLLECTOR_ADDRESS=staging-mobile-collector.newrelic.com` |
| Tune harvest cycle once for testing | Manual run → `nr_overrides='{"harvest_cycle_secs":60}'` |
| Add a stream for a single run | Manual run → `extra_streams='[{"id":"...","title":"..."...}]'` |
| Add a stream for ALL runs | UI → Variables → set `PLAYBACK_EXTRA_STREAMS=[{...}]` |
| Change a default in code | Edit `playback-config.json`, PR |

---

## Schedule (CI)

Two cron expressions. GitHub Actions cron is UTC-only (no native timezone), so the values are written as UTC; the IST column shows the equivalent local time.

| When | UTC cron | UTC time | IST time |
|---|---|---|---|
| **Daily comprehensive** | `30 3 * * *` | 03:30 | **09:00** |
| **Smoke every 6h** | `30 */6 * * *` | 00:30 / 06:30 / 12:30 / 18:30 | **06:00 / 12:00 / 18:00 / 00:00** |

To shift everything by N hours, add/subtract N from the UTC hour fields.

Plus push to `internal/video-rig` and manual `Run workflow`.

Both cron schedules use the same matrix; iOS-16 is OFF by default (slow runtime download). To run iOS-16 in cron, change `CRON_DEFAULT_iOS_16_iPhone_14` in the workflow's `env:` block, or trigger manually with the box checked.

---

## Matrix legs (5 parallel macOS runners)

| Tag | Device | OS | Pre-installed? |
|---|---|---|---|
| iOS-18-iPhone-17-Pro | iPhone 17 Pro | latest | ✓ |
| iOS-18-iPhone-16-Pro | iPhone 16 Pro | latest | ✓ |
| iOS-17-iPhone-15 | iPhone 15 | 17.5 | ✓ |
| iOS-16-iPhone-14 | iPhone 14 | 16.4 | downloads (+10 min) |
| tvOS-18-Apple-TV-4K | Apple TV 4K (3rd gen) | latest | ✓ |

`fail-fast: false` — one leg failing doesn't stop others.

Manual selection: workflow_dispatch has a boolean per leg.

---

## Don't halt on individual failures

- A failing scenario logs `[SCENARIO DONE] <id> → fail (continuing)` and the loop moves on.
- After the loop: `==> DEVICE COMPLETE: <leg-tag>` with a `<passed>/<total>` summary.
- The script exits 0 by default — failed scenarios surface in `SUMMARY.txt`, not as a red CI status.
- Set `FAIL_ON_ERROR=1` to make the script propagate non-zero (red status check).

---

## Artifacts

Each leg uploads `playback-<leg-tag>-<run_id>` containing:

```
build/playback-artifacts/
├── SUMMARY.txt                        ← pass/fail per scenario
├── pod-install.log
├── build.log
├── <id>/auto-play-<id>.log            ← full per-scenario log
└── <id>-screenshot.png                ← mid-playback frame
```

14-day retention.

---

## Adding a new content item

Without a PR (one of):

```bash
# Per-run via workflow input
extra_streams='[{"id":"my-test","title":"My Stream","subtitle":"...","streamURL":"https://...","isLive":false,"section":"vod","posterURL":null,"durationSecs":300}]'

# Or repo-wide via Settings → Variables
vars.PLAYBACK_EXTRA_STREAMS = '[{...}]'
```

`section` is `featured` / `live` / `vod`.

Permanent (committed): edit `NRSampleApp/ContentCatalog.swift` → PR.

---

## Local cert install (corporate networks only)

If your Mac sits behind Cloudflare Gateway / Zscaler / Netskope, simulator HTTPS fails with `-9802`. One-time fix per simulator:

```bash
security find-certificate -c "Gateway CA" -p /Library/Keychains/System.keychain > /tmp/gateway-ca.pem
xcrun simctl keychain booted add-root-cert /tmp/gateway-ca.pem
xcrun simctl shutdown booted; xcrun simctl boot $(xcrun simctl list devices booted | awk -F'[()]' '{print $2}' | head -1)
```

Not needed in CI (clean network).

---

## Project layout

```
Examples/iOS/NRSampleApp/
├── README.md                  this file
├── project.yml                XcodeGen source of truth (.xcodeproj is generated, gitignored)
├── Podfile                    NRVA pods, shared between iOS + tvOS targets
├── playback-config.json       NRVA defaults + per-leg overrides
├── NRSampleApp/
│   ├── NRSampleAppApp.swift   @main; calls NewRelicSetup.start()
│   ├── NewRelicSetup.swift    canonical NRVA wiring (the file customers copy)
│   ├── RootView.swift         routes --auto-play to PlayerView, else HomeView
│   ├── ContentItem.swift      Codable model
│   ├── ContentCatalog.swift   hardcoded + PLAYBACK_EXTRA_STREAMS injection
│   ├── HomeView.swift         catalog screen
│   ├── CardView.swift         reusable card with gradient placeholder
│   ├── PlayerView.swift       full-bleed AVKit + KVO observation + NRVA tracker
│   ├── AppLog.swift           file-based logger writing to Documents/logs/
│   └── LogViewerView.swift    in-app log viewer
└── scripts/
    └── run-playback.sh        the one runner

.github/workflows/
└── playback.yml               daily cron + every-6h + workflow_dispatch + push
```
