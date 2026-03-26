import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/place_model.dart';

class GeocodingService {
  final _dio = Dio();

  Future<List<Place>> search(String query, {double? lat, double? lng}) async {
    if (query.trim().length < 2) return [];

    final params = <String, dynamic>{
      'q': query,
      'access_token': AppConstants.mapboxAccessToken,
      'limit': 8,
      'language': 'en',
    };

    if (lat != null && lng != null) {
      params['proximity'] = '$lng,$lat';
    }

    final response = await _dio.get(
      'https://api.mapbox.com/search/geocode/v6/forward',
      queryParameters: params,
    );

    final features = response.data['features'] as List? ?? [];
    return features
        .map((f) => Place.fromMapboxFeature(f as Map<String, dynamic>))
        .toList();
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    final response = await _dio.get(
      'https://api.mapbox.com/search/geocode/v6/reverse',
      queryParameters: {
        'longitude': lng,
        'latitude': lat,
        'access_token': AppConstants.mapboxAccessToken,
        'limit': 1,
      },
    );

    final features = response.data['features'] as List? ?? [];
    if (features.isEmpty) return null;
    final props = features[0]['properties'] as Map<String, dynamic>? ?? {};
    return props['full_address'] as String? ?? props['name'] as String?;
  }
}
