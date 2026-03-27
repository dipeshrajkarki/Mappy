import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/place_model.dart';

class GeocodingService {
  final _dio = createApiClient();

  // Simple LRU cache: query -> results (max 50 entries)
  final _cache = <String, List<Place>>{};
  final _cacheOrder = <String>[];
  static const _maxCacheSize = 50;

  Future<List<Place>> search(String query, {double? lat, double? lng}) async {
    if (query.trim().length < 2) return [];

    final cacheKey = '${query.trim().toLowerCase()}|${lat?.toStringAsFixed(2)}|${lng?.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final params = <String, dynamic>{
      'q': query,
      'access_token': AppConstants.mapboxAccessToken,
      'limit': 8,
      'language': 'en',
    };

    if (lat != null && lng != null) {
      params['proximity'] = '$lng,$lat';
    }

    try {
      final response = await _dio.get(
        'https://api.mapbox.com/search/geocode/v6/forward',
        queryParameters: params,
      );

      final features = response.data['features'] as List? ?? [];
      final results = features
          .map((f) => Place.fromMapboxFeature(f as Map<String, dynamic>))
          .whereType<Place>()
          .toList();

      // Store in cache
      _cache[cacheKey] = results;
      _cacheOrder.add(cacheKey);
      if (_cacheOrder.length > _maxCacheSize) {
        final evicted = _cacheOrder.removeAt(0);
        _cache.remove(evicted);
      }

      return results;
    } on DioException catch (e) {
      debugPrint('Geocoding search error: ${e.type} — ${e.message}');
      return [];
    }
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
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
    } on DioException catch (e) {
      debugPrint('Reverse geocoding error: ${e.type} — ${e.message}');
      return null;
    }
  }
}
