# Sahayatra — Dev Resources & Repo References

> Honest assessment of every resource. No fluff.

---

## Map Foundation

### mapbox-maps-flutter (USE THIS — Already using)

- **Repo**: https://github.com/mapbox/mapbox-maps-flutter
- **pub.dev**: https://pub.dev/packages/mapbox_maps_flutter
- **Current in Mappy**: v2.4.0 → **Upgrade to v2.20.1**
- **Status**: Actively maintained by Mapbox (last release: March 2026)

**What it gives:**
- Full map rendering (Android + iOS)
- Camera control, viewport states, animations
- Route lines, markers, annotations
- 3D buildings (FillExtrusionLayer)
- 3D models (ModelLayer — stable since v2.17)
- User location puck (2D and 3D)
- FollowPuckViewportState — native nav camera (v2.20+)
- Offline maps

**Key upgrade features (v2.4 → v2.20):**
- `FollowPuckViewportState` with padding — replaces all manual camera math
- `BearingCourse` — auto-follows heading, no manual bearing smoothing
- Stable ModelLayer — 3D car models production-ready
- Batch annotation delete — `deleteMulti()`
- Shadow/lighting effects on buildings

**Verdict**: Core engine. Everything sits on top of this. UPGRADE ASAP.

---

## Official Examples (IMPORTANT)

### Mapbox Flutter Examples

- **Docs**: https://docs.mapbox.com/flutter/maps/examples/
- **In-repo examples**: https://github.com/mapbox/mapbox-maps-flutter/tree/main/example/lib

**47 example files including:**
- `model_layer_example.dart` — 3D model rendering
- `location_example.dart` — Location puck customization
- `camera_example.dart` — Camera animations, viewport states
- `animated_route_example.dart` — Route animation
- `traffic_layer_example.dart` — Traffic visualization
- `cluster_example.dart` — Marker clustering (useful for spotted pins)

**Verdict**: Copy real working patterns from here. Best learning resource.

---

## Navigation Wrappers

### flutter_mapbox_navigation (DON'T USE)

- **Repo**: https://github.com/eopeter/flutter_mapbox_navigation
- **Status**: Barely maintained (2 commits in 2024, 52 open issues)

**Problems:**
- Declares `sdk: <3.0.0` — won't compile with Dart 3.11+ (your project)
- Wraps Nav SDK v2.8 (from 2022) — 3 years outdated
- Android embedded view is broken (listed as "To Do")
- Xcode 16+ crashes (open issue)
- Off-route detection broken on iOS (open issue)

**Verdict**: Dead project. Skip.

### flutter_mapbox_navigation_v2_edition (DON'T USE)

- **Repo**: https://github.com/mostafaac30/flutter_mapbox_navigation_v2_edition
- **Status**: Abandoned (last commit: Nov 2022, 2 stars)

**Problems:**
- Same Dart 3 incompatibility
- Fork of the above with minimal changes
- Single commit (README update only)

**Verdict**: Even more dead. Skip.

---

## Other Repos

### Imperial-lord/mapbox-flutter (REFERENCE ONLY)

- **Repo**: https://github.com/Imperial-lord/mapbox-flutter
- **Status**: Demo/tutorial project, not a library

**What it is:**
- A sample app showing Maps + basic navigation in Flutter
- Good for seeing how someone structured a Mapbox Flutter app
- Uses older APIs

**Verdict**: Glance at it for structure ideas, don't copy code.

### flutter-mapbox-gl/maps (DON'T USE — DEPRECATED)

- **Repo**: https://github.com/flutter-mapbox-gl/maps
- **Status**: Deprecated. Replaced by `mapbox_maps_flutter`

**Why ChatGPT recommended it**: It was popular years ago. It's the OLD SDK.

**Verdict**: Ignore completely. You're already on the new SDK.

---

## What You Actually Need (Backend/Features)

### Firebase (USE — Backend)

- **Firestore**: Real-time location sync between group members
- **Auth**: Google/Apple sign-in
- **FCM**: Push notifications ("Alex is 20km ahead")
- **Storage**: Spotted photos
- **Cost**: $0 (free tier: 1GB storage, 50K reads/day, unlimited auth)
- **Packages**: `cloud_firestore`, `firebase_auth`, `firebase_messaging`, `firebase_storage`

### WebRTC — Walkie-Talkie (USE)

- **Package**: `flutter_webrtc` (https://pub.dev/packages/flutter_webrtc)
- **What it gives**: Peer-to-peer audio/video
- **Signaling**: Use Firebase Realtime DB for offer/answer/ICE exchange
- **Cost**: $0 (peer-to-peer, no server)
- **Alternative**: Record audio clips → upload to Firebase Storage → notify group (simpler V1)

### Background Location (USE)

- **Package**: `geolocator` (already using) + `flutter_background_service`
- **What it gives**: GPS tracking while app is in background
- **Critical for**: Location sharing to work while Google Maps is in foreground

### Google Maps / Waze Handoff (USE — No package needed)

- **How**: Deep link URLs, 5 lines of code
- **Package**: `url_launcher` (probably already in pubspec)
- **Cost**: $0 (just opens the other app)

### Text-to-Speech — Voice Alerts (OPTIONAL)

- **Package**: `flutter_tts` (https://pub.dev/packages/flutter_tts)
- **What it gives**: "Alex is 20 kilometers ahead" spoken aloud
- **Useful for**: Distance alerts while driving (don't want to look at phone)
- **Cost**: $0

---

## Summary Table

| Resource | Use? | Why |
|----------|------|-----|
| `mapbox_maps_flutter` v2.20 | YES | Core map engine, upgrade from v2.4 |
| Mapbox Flutter examples | YES | Learn patterns, copy code |
| `flutter_mapbox_navigation` | NO | Dead, Dart 3 incompatible |
| `flutter_mapbox_navigation_v2_edition` | NO | Even more dead |
| `Imperial-lord/mapbox-flutter` | Glance | Structure reference only |
| `flutter-mapbox-gl/maps` | NO | Deprecated, replaced by mapbox_maps_flutter |
| Firebase | YES | Backend, auth, real-time sync, notifications |
| `flutter_webrtc` | YES | Walkie-talkie |
| `geolocator` + background service | YES | Background location tracking |
| `url_launcher` | YES | Google Maps / Waze handoff |
| `flutter_tts` | OPTIONAL | Voice distance alerts |

---

## Architecture

```
Sahayatra (Flutter)
├── Mapbox Maps SDK v2.20      — Map rendering, route display, member markers
├── Firebase Firestore          — Real-time location sync, trip state
├── Firebase Auth               — Google/Apple sign-in
├── Firebase Messaging (FCM)    — Push notifications
├── WebRTC                      — Walkie-talkie (push-to-talk)
├── Background Location Service — GPS while app is backgrounded
├── URL Launcher                — Google Maps / Waze handoff
└── Flutter TTS (optional)      — Voice alerts

No custom navigation engine needed.
Google Maps handles turn-by-turn.
Your app handles everything Google Maps can't.
```

---

## Build Order

| Phase | What | Weeks |
|-------|------|-------|
| 1 | Project setup, Firebase, auth, trip create/join | 1 |
| 2 | Live location map — see all members in real-time | 1 |
| 3 | Google Maps/Waze handoff + distance notifications | 1 |
| 4 | Walkie-talkie (audio clip version first) | 1 |
| 5 | Spotted pins + trip itinerary | 1 |
| 6 | Polish, test on real devices, iOS build via Codemagic | 1 |
| 7 | Buffer / trip week | - |

---

## What Makes Sahayatra Unique

No single repo or SDK gives you this app. You're combining:

- **Mapbox** (map display + route preview)
- **Google Maps** (actual navigation — don't rebuild it)
- **Firebase** (real-time group sync)
- **WebRTC** (voice between cars)
- **Custom logic** (convoy alerts, distance tracking, spotted)

That combination doesn't exist anywhere. That's the product.
