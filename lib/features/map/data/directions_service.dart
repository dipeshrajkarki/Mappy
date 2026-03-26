import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/route_model.dart';

class DirectionsService {
  final _dio = Dio();

  /// Fetches route with traffic-aware timing.
  /// Returns the best route + up to 2 alternatives.
  Future<List<RouteInfo>> getRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving-traffic',
    bool alternatives = true,
  }) async {
    final coords = '$originLng,$originLat;$destLng,$destLat';

    final response = await _dio.get(
      'https://api.mapbox.com/directions/v5/mapbox/$profile/$coords',
      queryParameters: {
        'access_token': AppConstants.mapboxAccessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'banner_instructions': 'true',
        'alternatives': alternatives.toString(),
        'annotations': 'congestion,speed',
      },
    );

    final routesJson = response.data['routes'] as List;
    if (routesJson.isEmpty) throw Exception('No route found');

    return routesJson.map((r) => _parseRoute(r as Map<String, dynamic>)).toList();
  }

  /// Convenience: returns only the best route
  Future<RouteInfo> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final routes = await getRoutes(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );
    return routes.first;
  }

  RouteInfo _parseRoute(Map<String, dynamic> route) {
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordsList = geometry['coordinates'] as List;

    final points = coordsList.map((c) {
      final coord = c as List;
      return RoutePoint(
        latitude: (coord[1] as num).toDouble(),
        longitude: (coord[0] as num).toDouble(),
      );
    }).toList();

    final legs = route['legs'] as List;
    final steps = <RouteStep>[];

    // Parse congestion data for traffic coloring
    final congestionSegments = <String>[];
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final annotation = legMap['annotation'] as Map<String, dynamic>?;
      if (annotation != null) {
        final congestion = annotation['congestion'] as List?;
        if (congestion != null) {
          congestionSegments.addAll(congestion.cast<String>());
        }
      }

      final legSteps = legMap['steps'] as List;
      for (final step in legSteps) {
        final s = step as Map<String, dynamic>;
        final maneuver = s['maneuver'] as Map<String, dynamic>;
        final location = maneuver['location'] as List;
        final name = s['name'] as String? ?? '';

        steps.add(RouteStep(
          instruction: maneuver['instruction'] as String? ?? '',
          distanceMeters: (s['distance'] as num).toDouble(),
          durationSeconds: (s['duration'] as num).toDouble(),
          maneuver: maneuver['type'] as String? ?? '',
          streetName: name,
          location: RoutePoint(
            latitude: (location[1] as num).toDouble(),
            longitude: (location[0] as num).toDouble(),
          ),
        ));
      }
    }

    return RouteInfo(
      points: points,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      steps: steps,
      congestion: congestionSegments,
    );
  }
}
