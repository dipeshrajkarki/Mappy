import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';

class MapMatchingService {
  final _dio = Dio();

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
          matchings[0]['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List;
      if (coords.isEmpty) return null;

      final first = coords[0] as List;
      return (
        (first[1] as num).toDouble(),
        (first[0] as num).toDouble(),
        heading,
      );
    } catch (_) {
      return null;
    }
  }
}
