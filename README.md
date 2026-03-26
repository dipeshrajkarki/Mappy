# Mappy

A personal navigation app built with Flutter and Mapbox. Dark theme, traffic-aware routing, 3D buildings, and smooth driving experience.

## Tech Stack

- **Flutter** (Dart 3.11+)
- **mapbox_maps_flutter** — Official Mapbox Maps SDK for Flutter
- **geolocator** — Live GPS positioning and speed
- **flutter_riverpod** — State management
- **dio** — HTTP client for Mapbox APIs

## Features

### Map & Display
- Fullscreen Mapbox dark map (`dark-v11` style)
- 3D extruded buildings (visible at zoom 14+)
- Lime/yellow navigation arrow that follows heading
- Smooth camera transitions with `easeTo` animations
- North-up / heading-up toggle during navigation

### Navigation
- Search destinations using Mapbox Geocoding API
- Traffic-aware routing via Mapbox Directions API (`driving-traffic` profile)
- Route segments colored by congestion level (green/yellow/orange/red)
- Turn-by-turn instructions with street names
- Start and Destination labels on the route
- ETA, distance, and duration display

### Driving Modes
- **Route navigation** — Full turn-by-turn with instructions panel
- **Just drive** — Free driving mode with windshield camera (65 pitch), speed display, no destination needed
- **Simulation** — Fake GPS driving around Oslo for testing (smooth interpolation at ~30fps)

### UI
- Dark theme with lime (#CDDC39) accent colors
- Animated slide-up panels and fade transitions
- "Your Trip" home screen with From/To fields
- Editable origin — tap "My location" to set a custom start point
- Pressable button animations

## Project Structure

```
lib/
├── main.dart                          # App entry point, Mapbox token init
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Mapbox token, style URL, map defaults
│   ├── theme/
│   │   └── app_theme.dart             # Dark theme, colors, spacing, glassmorphism
│   └── widgets/
│       └── animated_panel.dart        # SlideUpPanel, SlideDownPanel, FadeIn, Pressable
├── features/
│   └── map/
│       ├── application/
│       │   ├── location_provider.dart # Riverpod GPS provider + simulation engine
│       │   └── navigation_provider.dart # Navigation state machine
│       ├── data/
│       │   ├── directions_service.dart # Mapbox Directions API (traffic-aware)
│       │   └── geocoding_service.dart  # Mapbox Geocoding API (search + reverse)
│       ├── domain/
│       │   ├── place_model.dart        # Place search result model
│       │   └── route_model.dart        # RouteInfo, RouteStep, RoutePoint, congestion
│       └── presentation/
│           ├── map_screen.dart         # Main screen — map, overlays, all UI states
│           └── widgets/
│               ├── navigation_panel.dart    # Turn instruction top bar + ETA bottom bar
│               ├── route_preview_panel.dart # Route info + "Start my trip" button
│               ├── search_sheet.dart        # Animated full-screen search
│               └── speed_indicator.dart     # Speed km/h glassmorphic widget
```

## Navigation State Machine

```
NavMode.idle        -> Home screen with "Your Trip" panel
NavMode.searching   -> Full-screen search sheet (origin or destination)
NavMode.routePreview -> Route on map + info panel + Start button
NavMode.navigating  -> Turn-by-turn with instructions + ETA
NavMode.driving     -> Free driving, windshield camera, speed only
```

## Setup

### 1. Mapbox Access Token

Replace the placeholder token in these files with your Mapbox public token:

- `lib/core/constants/app_constants.dart` — line 5
- `android/app/src/main/AndroidManifest.xml` — meta-data tag
- `ios/Runner/Info.plist` — MBXAccessToken key

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run

```bash
# Android emulator or device
flutter run

# Build APK
flutter build apk --debug
```

### 4. Custom Car Icon (Optional)

Drop a PNG image at `assets/icons/car.png` (top-down view, ~80x80px, pointing UP).
The app will automatically use it instead of the default lime arrow.

## Platform Requirements

### Android
- minSdk: 21 (Android 5.0+)
- Location permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- Internet permission for map tiles and API calls

### iOS
- iOS 14+
- `NSLocationWhenInUseUsageDescription` in Info.plist
- `MBXAccessToken` in Info.plist
- For SDK download: secret token in `~/.netrc`

## APIs Used

| API | Purpose | Auth |
|-----|---------|------|
| Mapbox Maps | Map tiles, 3D buildings, dark style | Public token |
| Mapbox Geocoding v6 | Place search, reverse geocoding | Public token |
| Mapbox Directions v5 | Route calculation, traffic, turn instructions | Public token |
| Device GPS (geolocator) | Live position, speed, heading | Location permission |

## Simulation Mode

For testing without a real GPS signal:

1. Tap **"Simulate"** on the home screen
2. A fake GPS position drives around central Oslo at ~40-60 km/h
3. The navigation arrow moves smoothly (interpolated at ~30fps)
4. Speed indicator shows realistic values
5. You can search destinations and start navigation while simulating

## Future Improvements

- Voice turn-by-turn instructions (TTS)
- Multiple route alternatives displayed on map
- Search history and favorite places
- Speed limit warnings
- Off-route detection and auto-recalculation
- Lane guidance visualization
- Live traffic overlay on map
- Day/night map style auto-switch
