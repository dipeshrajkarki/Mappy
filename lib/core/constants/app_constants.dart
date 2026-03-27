import 'secrets.dart' as secrets;

class AppConstants {
  AppConstants._();

  // Mapbox
  static const String mapboxAccessToken = secrets.mapboxAccessToken;
  static const String mapboxStyleUrl = 'mapbox://styles/mapbox/dark-v11';

  // Map defaults (Oslo, Norway)
  static const double defaultLat = 59.9139;
  static const double defaultLng = 10.7522;
  static const double defaultZoom = 13.0;
  static const double navigationZoom = 16.0;

  // Simulation
  static const double simSpeedMps = 13.9; // ~50 km/h
  static const int simTickMs = 33; // ~30fps

  // Camera — street-level navigation view (close to car, can see lanes)
  static const double navPitch = 65.0;
  static const double navZoom = 19.0;
  static const double navOffsetMeters = 20.0;
  static const int cameraAnimDriveMs = 400;
  static const int cameraAnimIdleMs = 800;

  // Navigation thresholds
  static const double stepDetectionMeters = 30.0;
  static const double destinationDetectionMeters = 50.0;
  static const int searchDebounceMs = 400;
  static const int navUpdateIntervalSec = 2;

  // Traffic colors
  static const int trafficSevere = 0xFFE53935;
  static const int trafficHeavy = 0xFFFF8F00;
  static const int trafficModerate = 0xFFFFD600;

  // 3D buildings
  static const int buildingColor = 0xFF1A1A2E;
  static const double buildingMinZoom = 14.0;
  static const double buildingOpacity = 0.7;
}
