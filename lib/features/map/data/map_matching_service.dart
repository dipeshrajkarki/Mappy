import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

class MapMatchingService {
  final _dio = createApiClient();

  /// Snaps a coordinate to the nearest road.
  /// Returns (lat, lng, bearing) or null if no road nearby.
  Future<(double, double, double)?> snapToRoad(
      double lat, double lng, double heading) async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/matching/v5/mapbox/driving/'
        '$lng,$lat',
        queryParameters: {
          'access_token': AppConstants.mapboxAccessToken,
          'geometries': 'geojson',
          'radiuses': '50',
          'bearings': '${heading.round()},45',
          'steps': 'false',
        },
      );

      final matchings = response.data['matchings'] as List?;
      if (matchings == null || matchings.isEmpty) return null;

      final geometry =
          matchings[0]['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return null;

      final first = coords[0] as List;
      if (first.length < 2) return null;

      return (
        (first[1] as num).toDouble(),
        (first[0] as num).toDouble(),
        heading,
      );
    } on DioException catch (e) {
      debugPrint('Map matching error: ${e.type} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Map matching parse error: $e');
      return null;
    }
  }
}
