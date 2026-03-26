# CLAUDE.md

## Project Overview
Mappy is a personal navigation app built with Flutter and Mapbox. It provides turn-by-turn navigation, traffic-aware routing, 3D buildings, and a smooth driving experience with a dark themed UI.

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
    ├── data/        — API services (geocoding, directions)
    ├── domain/      — models (Place, RouteInfo, RouteStep)
    └── presentation/ — screens and widgets
```

## Navigation State Machine
`NavMode` enum drives all UI:
- `idle` — home screen with "Your Trip" panel
- `searching` — full-screen search (for origin or destination)
- `routePreview` — route on map + info panel + "Start my trip" button
- `navigating` — turn-by-turn with instructions, ETA, speed
- `driving` — free driving mode, windshield camera, no destination

## Key Design Decisions
- **Dark theme** with lime/yellow (#CDDC39) accents
- **Traffic-aware routing** via `driving-traffic` Mapbox profile
- **3D buildings** via FillExtrusionLayer on the dark map style
- **Smooth simulation** — interpolated GPS at ~30fps for testing
- **Custom car icon** — drop `assets/icons/car.png` to override default arrow
- **Camera modes** — 65 degree pitch + heading-follow in drive/nav, north-up toggle available
- **Editable origin** — "From" field supports custom starting point via search

## APIs
- Mapbox Geocoding v6: `https://api.mapbox.com/search/geocode/v6/forward`
- Mapbox Directions v5: `https://api.mapbox.com/directions/v5/mapbox/driving-traffic/`
- All API calls use the Mapbox public access token from `AppConstants`

## What NOT to do
- Don't add Firebase unless explicitly asked
- Don't add multiple state management systems
- Don't overengineer — keep it simple
- Don't add backend/server dependencies — all APIs are client-side
- Don't change the dark theme to light without asking

## Running
```bash
flutter pub get
flutter run           # on connected device/emulator
flutter build apk     # build Android APK
```

## Token Setup
Mapbox public token must be set in 3 places:
1. `lib/core/constants/app_constants.dart`
2. `android/app/src/main/AndroidManifest.xml`
3. `ios/Runner/Info.plist`
