# Mappy

A personal navigation app built with Flutter and Mapbox. Dark theme, traffic-aware routing, 3D buildings, route simulation, and a smooth driving experience.

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
- Navigation arrow / 3D car model on the map
- Windshield camera view (55 pitch, camera offset behind car)
- North-up / heading-up toggle during navigation
- Smooth `easeTo` camera transitions

### Navigation
- Search destinations using Mapbox Geocoding API
- Traffic-aware routing via Mapbox Directions API (`driving-traffic` profile)
- Route mode selector: drive / walk / cycle
- Route segments colored by congestion level (green/yellow/orange/red)
- Turn-by-turn instructions with street names
- Start and Destination labels on the route
- ETA, distance, and duration display

### Driving Modes
- **Route navigation** — Turn-by-turn with instructions, ETA, speed
- **Simulated navigation** — Car drives along the actual route at ~50 km/h for testing
- **Just drive** — Free driving mode with windshield camera, no destination
- **D-Pad** — Virtual joystick to manually drive the car around the map

### Vehicle Models
- 2D lime chevron arrow (`classic`)
- 3D `.glb` models: `sedan`, `suv`, `taxi`, `truck`
- Vehicle selector bottom sheet to switch between models
- Custom car icon support via `assets/icons/car.png`

### UI
- Dark theme with lime (#CDDC39) accent colors
- Animated slide-up panels and fade transitions
- "Your Trip" home screen with From/To fields
- Editable origin — tap "My location" to set a custom start point
- Glassmorphism containers and pressable button animations

## Project Structure

```
lib/
├── main.dart                              # App entry, Mapbox token init
├── core/
│   ├── constants/
│   │   ├── app_constants.dart             # Mapbox style URL, map defaults
│   │   ├── secrets.dart                   # Mapbox token (gitignored)
│   │   └── secrets.example.dart           # Token template (committed)
│   ├── theme/
│   │   └── app_theme.dart                 # Dark theme, colors, spacing, glass
│   └── widgets/
│       └── animated_panel.dart            # SlideUp, SlideDown, FadeIn, Pressable
├── features/
│   └── map/
│       ├── application/
│       │   ├── location_provider.dart     # GPS + route sim + D-pad driving
│       │   └── navigation_provider.dart   # Nav state machine + routing profiles
│       ├── data/
│       │   ├── directions_service.dart    # Mapbox Directions API (traffic)
│       │   ├── geocoding_service.dart     # Mapbox Geocoding API (search)
│       │   └── map_matching_service.dart  # Mapbox Map Matching API (road snap)
│       ├── domain/
│       │   ├── place_model.dart           # Place search result
│       │   └── route_model.dart           # RouteInfo, RouteStep, RoutingProfile
│       └── presentation/
│           ├── map_screen.dart            # Main screen — map, overlays, all states
│           └── widgets/
│               ├── drive_pad.dart         # Virtual D-pad joystick
│               ├── navigation_panel.dart  # Turn instruction + ETA bars
│               ├── route_preview_panel.dart # Route info + mode selector + Start/Test
│               ├── search_sheet.dart      # Animated search screen
│               └── speed_indicator.dart   # Speed km/h widget
```

## Navigation State Machine

```
NavMode.idle         -> Home screen with "Your Trip" panel
NavMode.searching    -> Full-screen search (origin or destination)
NavMode.routePreview -> Route on map + drive/walk/cycle selector + Start/Test buttons
NavMode.navigating   -> Turn-by-turn with instructions + ETA (real GPS or simulated)
NavMode.driving      -> Free driving, windshield camera, speed only
```

## Setup

### 1. Mapbox Access Token

Copy the secrets template and add your real token:

```bash
cp lib/core/constants/secrets.example.dart lib/core/constants/secrets.dart
```

Edit `secrets.dart` and replace `YOUR_MAPBOX_PUBLIC_TOKEN_HERE` with your token.

The token is gitignored — it will never be committed.

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run

```bash
# Android device or emulator
flutter run

# Build APK
flutter build apk --debug
```

### 4. 3D Car Models (Optional)

Place `.glb` files in `assets/models/`. Included models:
- `sedan.glb` (~172KB)
- `suv.glb` (~208KB)
- `taxi.glb` (~176KB)
- `truck.glb` (~176KB)

Select a model from the vehicle selector in the app.

### 5. Custom 2D Icon (Optional)

Drop a PNG at `assets/icons/car.png` (top-down view, pointing UP).
It replaces the default lime arrow when `classic` mode is selected.

## Platform Requirements

### Android
- minSdk: 21 (Android 5.0+)
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`

### iOS
- iOS 14+
- Location usage descriptions in Info.plist
- For Mapbox SDK download: secret token in `~/.netrc`

## APIs Used

| API | Purpose | Auth |
|-----|---------|------|
| Mapbox Maps | Map tiles, 3D buildings, dark style | Public token |
| Mapbox Geocoding v6 | Place search, reverse geocoding | Public token |
| Mapbox Directions v5 | Routes (drive/walk/cycle), traffic, turns | Public token |
| Mapbox Map Matching v5 | Snap coordinates to nearest road | Public token |
| Device GPS (geolocator) | Live position, speed, heading | Location permission |

## Testing Without Driving

### Route Simulation (recommended)
1. Search a destination (e.g. "Oslo Opera House")
2. See the route preview with duration/distance
3. Tap **Test** — the car drives along the actual route at ~50 km/h
4. Turn-by-turn instructions update as the car moves
5. Camera follows from behind in windshield view
6. Navigation ends automatically when the car arrives

### D-Pad Manual Driving
1. Tap **D-Pad** on the home screen
2. Use the virtual joystick: up=accelerate, down=brake, left/right=steer
3. Car moves freely (not locked to roads)
4. Good for quickly testing camera/UI without waiting for a route

## Future Improvements

- Voice turn-by-turn instructions (TTS)
- Multiple route alternatives displayed on map
- Search history and favorite places
- Speed limit warnings
- Off-route detection and auto-recalculation
- Lane guidance visualization
- Live traffic overlay on map
- Day/night map style auto-switch
