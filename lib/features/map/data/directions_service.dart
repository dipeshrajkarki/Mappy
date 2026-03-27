import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/route_model.dart';

class DirectionsService {
  final _dio = createApiClient();

  /// Fetches route with traffic-aware timing.
  /// Returns the best route + up to 2 alternatives.
  Future<List<RouteInfo>> getRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    RoutingProfile profile = RoutingProfile.drivingTraffic,
    bool alternatives = true,
  }) async {
    final coords = '$originLng,$originLat;$destLng,$destLat';

    try {
      final response = await _dio.get(
        'https://api.mapbox.com/directions/v5/mapbox/${profile.apiString}/$coords',
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

      final routesJson = response.data['routes'] as List?;
      if (routesJson == null || routesJson.isEmpty) {
        throw Exception('No route found');
      }

      return routesJson
          .map((r) => _parseRoute(r as Map<String, dynamic>, profile))
          .toList();
    } on DioException catch (e) {
      debugPrint('Directions API error: ${e.type} — ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timed out. Check your connection.');
      }
      throw Exception('Could not fetch route. Try again.');
    }
  }

  /// Convenience: returns only the best route
  Future<RouteInfo> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    RoutingProfile profile = RoutingProfile.drivingTraffic,
  }) async {
    final routes = await getRoutes(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      profile: profile,
    );
    return routes.first;
  }

  RouteInfo _parseRoute(Map<String, dynamic> route, RoutingProfile profile) {
    final geometry = route['geometry'] as Map<String, dynamic>?;
    if (geometry == null) throw Exception('Invalid route geometry');

    final coordsList = geometry['coordinates'] as List? ?? [];

    final points = coordsList.map((c) {
      final coord = c as List;
      if (coord.length < 2) throw Exception('Invalid coordinate data');
      return RoutePoint(
        latitude: (coord[1] as num).toDouble(),
        longitude: (coord[0] as num).toDouble(),
      );
    }).toList();

    final legs = route['legs'] as List? ?? [];
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

      final legSteps = legMap['steps'] as List? ?? [];
      for (final step in legSteps) {
        final s = step as Map<String, dynamic>;
        final maneuver = s['maneuver'] as Map<String, dynamic>?;
        if (maneuver == null) continue;

        final location = maneuver['location'] as List?;
        if (location == null || location.length < 2) continue;

        final name = s['name'] as String? ?? '';

        // Parse lane guidance
        final intersections = s['intersections'] as List?;
        var lanes = <LaneInfo>[];
        if (intersections != null && intersections.isNotEmpty) {
          final firstIntersection = intersections.first as Map<String, dynamic>;
          final lanesJson = firstIntersection['lanes'] as List?;
          if (lanesJson != null) {
            lanes = lanesJson
                .map((l) => LaneInfo.fromJson(l as Map<String, dynamic>))
                .toList();
          }
        }

        steps.add(RouteStep(
          instruction: maneuver['instruction'] as String? ?? '',
          distanceMeters: (s['distance'] as num?)?.toDouble() ?? 0,
          durationSeconds: (s['duration'] as num?)?.toDouble() ?? 0,
          maneuver: maneuver['type'] as String? ?? '',
          streetName: name,
          lanes: lanes,
          location: RoutePoint(
            latitude: (location[1] as num).toDouble(),
            longitude: (location[0] as num).toDouble(),
          ),
        ));
      }
    }

    return RouteInfo(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      steps: steps,
      congestion: congestionSegments,
      profile: profile,
    );
  }
}
