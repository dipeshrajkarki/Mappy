class RouteInfo {
  final List<RoutePoint> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final List<String> congestion; // per-segment: low, moderate, heavy, severe

  const RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    this.congestion = const [],
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationText {
    final totalMin = (durationSeconds / 60).round();
    if (totalMin < 60) return '$totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return '${h}h ${m}m';
  }

  String get etaText {
    final arrival = DateTime.now().add(Duration(seconds: durationSeconds.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get hasTrafficData => congestion.isNotEmpty;
}

class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({required this.latitude, required this.longitude});
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuver;
  final String streetName;
  final RoutePoint location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuver,
    required this.location,
    this.streetName = '',
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }
}
