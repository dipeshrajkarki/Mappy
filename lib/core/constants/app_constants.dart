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
}
