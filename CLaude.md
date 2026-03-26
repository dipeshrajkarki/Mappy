# CLAUDE.md

## Project Overview
Mappy is a personal navigation app built with Flutter and Mapbox. It provides turn-by-turn navigation, traffic-aware routing, 3D buildings, route simulation, and a smooth driving experience with a dark themed UI.

## Tech Stack
- **Flutter** (Dart 3.11+) — cross-platform mobile framework
- **mapbox_maps_flutter** — official Mapbox Maps SDK (dark-v11 style, 3D buildings)
- **geolocator** — device GPS, speed, heading
- **flutter_riverpod** — state management (StateNotifierProvider)
- **dio** — HTTP client for Mapbox Geocoding + Directions APIs

## Architecture
Feature-based clean architecture:
```
lib/
├── main.dart
├── core/           — constants, theme, reusable widgets
└── features/map/
    ├── application/ — Riverpod providers (location, navigation state machine)
    ├── data/        — API services (geocoding, directions, map matching)
    ├── domain/      — models (Place, RouteInfo, RouteStep, RoutingProfile)
    └── presentation/ — screens and widgets (map, search, nav panels, D-pad)
```

## Navigation State Machine
`NavMode` enum drives all UI:
- `idle` — home screen with "Your Trip" panel, From/To fields, Drive/D-Pad buttons
- `searching` — full-screen search (for origin or destination)
- `routePreview` — route on map + drive/walk/cycle selector + Start/Test buttons
- `navigating` — turn-by-turn with instructions, ETA, speed (real GPS or simulated)
- `driving` — free driving mode, windshield camera, no destination

## Routing Profiles
`RoutingProfile` enum with Mapbox Directions API profiles:
- `drivingTraffic` — car routing with live traffic (`driving-traffic`)
- `walking` — pedestrian routing (`walking`)
- `cycling` — bike routing (`cycling`)

## Simulation Modes
- **Route simulation** — car drives along actual route geometry at ~50 km/h
- **D-Pad** — virtual joystick for manual driving (off-road, for quick UI testing)
- Both modes show the navigation arrow, disable native GPS puck, and enable windshield camera

## Vehicle System
- `classic` — 2D lime chevron arrow (generated programmatically)
- 3D `.glb` models in `assets/models/`: sedan, suv, taxi, truck
- Vehicle selector bottom sheet to switch models
- 3D models use Mapbox `ModelLayer` + `GeoJsonSource`
- 2D arrow uses `PointAnnotation` with rotation

## Key Design Decisions
- **Dark theme** with lime/yellow (#CDDC39) accents
- **Traffic-aware routing** via `driving-traffic` Mapbox profile
- **3D buildings** via FillExtrusionLayer on the dark map style
- **Route simulation at realistic speed** — 50 km/h, progress-based interpolation along route geometry
- **Windshield camera** — 55 pitch, camera offset 40m behind heading, heading-follow
- **Camera lock during simulation** — scroll listener disabled during fake GPS to prevent camera detaching
- **North-up toggle** — compass button switches between heading-up and north-up views
- **Editable origin** — "From" field supports custom starting point via search
- **Token security** — Mapbox token in gitignored `secrets.dart`, set via `MapboxOptions.setAccessToken()` in Dart (not in platform configs)

## APIs
- Mapbox Geocoding v6: `https://api.mapbox.com/search/geocode/v6/forward`
- Mapbox Directions v5: `https://api.mapbox.com/directions/v5/mapbox/{profile}/`
- Mapbox Map Matching v5: `https://api.mapbox.com/matching/v5/mapbox/driving/`
- All API calls use the Mapbox public access token from `secrets.dart` via `AppConstants`

## What NOT to do
- Don't add Firebase unless explicitly asked
- Don't add multiple state management systems
- Don't overengineer — keep it simple
- Don't add backend/server dependencies — all APIs are client-side
- Don't change the dark theme to light without asking
- Don't commit `secrets.dart` — it's gitignored for a reason

## Running
```bash
flutter pub get
flutter run           # on connected device/emulator
flutter build apk     # build Android APK
```

## Token Setup
1. Copy `lib/core/constants/secrets.example.dart` to `secrets.dart`
2. Replace placeholder with your real Mapbox public token
3. The token is loaded at app startup via `MapboxOptions.setAccessToken()`
