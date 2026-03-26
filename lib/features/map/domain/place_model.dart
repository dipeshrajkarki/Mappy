class Place {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const Place({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory Place.fromMapboxFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List;

    return Place(
      name: props['name'] as String? ?? props['full_address'] as String? ?? 'Unknown',
      address: props['full_address'] as String? ?? props['place_formatted'] as String? ?? '',
      latitude: (coords[1] as num).toDouble(),
      longitude: (coords[0] as num).toDouble(),
    );
  }
}
