# NRSampleApp — Feature Checklist

Modern iOS video reference app for the New Relic Video Agent.
SwiftUI, iOS 15+, ObjC pods.

**v1 principle:** every feature uses free or free-to-test resources. No paid services required.

Cost flags: **🆓** free always, **🧪** free for testing only (paid for prod), **💰** paid even for testing.

---

## v1 scope (in)

### A. Modern UI / UX patterns
- [ ] A1 Dark mode by default 🆓
- [ ] A2 Player auto-fading controls (3s idle → fade) 🆓
- [ ] A3 Scrubbing thumbnail preview (HLS image trickplay) 🆓
- [ ] A4 10s back / forward buttons (double-tap zones) 🆓
- [ ] A6 Vertical swipe = brightness/volume 🆓
- [ ] A7 Horizontal swipe = seek 🆓
- [ ] A8 Bottom-sheet picker (quality / speed / audio / subtitles) 🆓
- [ ] A9 Loading skeleton states 🆓
- [ ] A10 Error states with retry 🆓
- [ ] A11 Live indicator (red dot + "LIVE" badge) 🆓
- [ ] A12 Stats overlay toggle (bitrate, dropped frames, buffer) 🆓
- [ ] A13 Event-log overlay (NRVA events live) — required for tests 🆓

### B. Playback formats
- [ ] B1 HLS adaptive VOD 🆓
- [ ] B2 HLS live (no DVR) 🆓
- [ ] B3 HLS live with DVR 🆓
- [ ] B5 Progressive MP4 🆓

### C. DRM
- [ ] C1 Clear (no DRM) 🆓
- [ ] C2 FairPlay with TEST license server 🧪

### D. Ads
- [ ] D1 IMA pre-roll 🆓
- [ ] D2 IMA mid-roll pod 🆓
- [ ] D3 IMA VMAP playlist 🆓
- [ ] D4 IMA post-roll 🆓

### E. Native iOS player features
- [ ] E1 Picture-in-Picture (auto + manual) 🆓
- [ ] E2 AirPlay 🆓
- [ ] E3 Background audio (with entitlement) 🆓
- [ ] E4 Lock-screen Now Playing controls 🆓
- [ ] E7 Playback rate 0.5× / 1× / 1.5× / 2× 🆓
- [ ] E8 Quality forcing (auto / 1080p / 720p / 480p) 🆓
- [ ] E9 Multi-audio track switching 🆓
- [ ] E10 Subtitle styling (size, color, background) 🆓

### F. Resilience / failure modes
- [ ] F1 Network throttle (NLC profiles: 56k / 200k / 1M / wifi) 🆓
- [ ] F2 App backgrounding mid-playback 🆓

### G. Cast / share
- [ ] G1 AirPlay (built-in) 🆓

### H. NewRelic agent integration (the actual point)
- [ ] H1 QoE enabled by default 🆓
- [ ] H2 CONTENT_* events firing 🆓
- [ ] H3 AD_* events firing (with ad scenarios) 🆓
- [ ] H4 SEEK_START / SEEK_END (auto + manual API) 🆓
- [ ] H5 Custom attributes per session 🆓
- [ ] H6 User ID / content metadata 🆓
- [ ] H7 Multi-tracker (content + ad pair) 🆓
- [ ] H9 BUFFER_START / BUFFER_END validation 🆓

**v1 total: ~31 items.**

---

## v1.1+ (deferred)

- [ ] D5 AWS MediaTailor SSAI — VOD (demo session URL) 🧪
- [ ] D6 AWS MediaTailor SSAI — live 🧪
- [ ] B4 LL-HLS (low-latency HLS)
- [ ] B6 HLS with multi-audio tracks (player feature done in E9; format-side validation here)
- [ ] B7 HLS with WebVTT / IMSC1 subtitles
- [ ] A5 Skip intro / credits buttons (needs metadata standard)
- [ ] E5 Dynamic Island integration (iOS 16.1+)
- [ ] E6 Spatial audio
- [ ] E11 Closed captions for live (CEA-608/708)
- [ ] F3 Live → VOD transition
- [ ] F4 Crash + restart with state recovery
- [ ] F5 8h continuous stability run
- [ ] F6 Multi-player simultaneous
- [ ] F7 Multi-CDN failover (needs 2+ stream sources)
- [ ] F8 Token-authenticated stream
- [ ] H8 Tracker switching (AVPlayer → Brightcove mid-app)

---

## Out of scope (forever, unless reversed)

- ❌ Brightcove SSAI / Brightcove SDK 💰 — paid account
- ❌ Production FairPlay license server 💰 — test server is enough
- ❌ Chromecast / Google Cast SDK — AirPlay covers Apple ecosystem

---

## Test resources (free, public)

### HLS streams
- Apple BipBop adaptive: `https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8`
- Apple BipBop FPS (FairPlay test): `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8`
- Bitmovin Sintel (with FairPlay demo): `https://bitmovin-a.akamaihd.net/content/sintel/hls/playlist.m3u8`
- Mux test stream: `https://stream.mux.com/Sc89iWAyNkhJ3P1rQ02nrEdCFTnfT01CZ2KmaEcxXfB008.m3u8`
- Akamai live demo: `https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8`

### IMA test ad tags (Google's public)
- Single inline pre-roll: `https://pubads.g.doubleclick.net/gampad/ads?...&iu=/21775744923/external/single_preroll_skippable&...`
- VMAP standard pods: `https://pubads.g.doubleclick.net/gampad/ads?...&iu=/21775744923/external/vmap_ad_samples&...`
  (full URLs in scenario manifests when written)

### Progressive MP4
- Apple BigBuckBunny: `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4`

---

## Notes on costs

- **Apple Developer Account** ($99/yr) — likely already in place. Required for FairPlay SDK and on-device testing.
- All test streams above are public and free-to-use for development.
- IMA SDK is free; ads themselves cost the *publisher* (not us — we're using their test inventory).
- MediaTailor demo endpoints are free / rate-limited. For prod use, customers pay per-ad-break + per-minute.

---

## Architecture (one-line summary)

Each checklist item = one scenario YAML manifest + one SwiftUI view + one XCUITest function. Adding new items is mechanical.

See `PLAN.md` (forthcoming) for the workflow + scenario manifest format.
