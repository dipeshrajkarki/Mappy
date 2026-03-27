import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';
import '../data/map_matching_service.dart';
import '../domain/route_model.dart';

class LocationState {
  final double? latitude;
  final double? longitude;
  final double speedMps;
  final double heading;
  final bool hasPermission;
  final bool isTracking;
  final bool isSimulating;
  final String? error;
  final bool permissionDeniedForever;

  const LocationState({
    this.latitude,
    this.longitude,
    this.speedMps = 0,
    this.heading = 0,
    this.hasPermission = false,
    this.isTracking = false,
    this.isSimulating = false,
    this.error,
    this.permissionDeniedForever = false,
  });

  double get speedKmh => max(0, speedMps * 3.6);
  bool get hasLocation => latitude != null && longitude != null;
  bool get isFakeGps => isSimulating;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    double? speedMps,
    double? heading,
    bool? hasPermission,
    bool? isTracking,
    bool? isSimulating,
    String? error,
    bool? permissionDeniedForever,
    bool clearError = false,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedMps: speedMps ?? this.speedMps,
      heading: heading ?? this.heading,
      hasPermission: hasPermission ?? this.hasPermission,
      isTracking: isTracking ?? this.isTracking,
      isSimulating: isSimulating ?? this.isSimulating,
      error: clearError ? null : (error ?? this.error),
      permissionDeniedForever:
          permissionDeniedForever ?? this.permissionDeniedForever,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  StreamSubscription<Position>? _positionSub;
  Timer? _simTimer;
  VoidCallback? onSimulationFinished;
  final _mapMatching = MapMatchingService();
  bool _snapToRoad = false;

  // Route simulation — moves at realistic speed along route geometry
  List<RoutePoint> _routePoints = [];
  int _simIndex = 0;
  double _simProgress = 0; // 0..1 progress within current segment
  double _simSegmentDist = 0;
  static const _simSpeedMps = AppConstants.simSpeedMps;
  static const _simTickMs = AppConstants.simTickMs;

  // ==========================================
  // GPS init
  // ==========================================

  Future<void> init() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(error: 'Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(error: 'Location permission denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        error: 'Location permanently denied. Tap to open settings.',
        permissionDeniedForever: true,
      );
      return;
    }

    state = state.copyWith(hasPermission: true, clearError: true);
    _startTracking();
  }

  /// Enable/disable road snapping for real GPS positions
  void setSnapToRoad(bool enabled) => _snapToRoad = enabled;

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (pos) {
        if (!state.isFakeGps) {
          if (_snapToRoad) {
            _snapAndUpdate(pos);
          } else {
            state = state.copyWith(
              latitude: pos.latitude,
              longitude: pos.longitude,
              speedMps: pos.speed,
              heading: pos.heading,
              isTracking: true,
            );
          }
        }
      },
      onError: (e) => state = state.copyWith(error: 'Location error: $e'),
    );
  }

  Future<void> _snapAndUpdate(Position pos) async {
    final snapped = await _mapMatching.snapToRoad(
      pos.latitude,
      pos.longitude,
      pos.heading,
    );
    if (!mounted) return;

    if (snapped != null) {
      state = state.copyWith(
        latitude: snapped.$1,
        longitude: snapped.$2,
        speedMps: pos.speed,
        heading: snapped.$3,
        isTracking: true,
      );
    } else {
      // Fallback to raw GPS if no road match
      state = state.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        heading: pos.heading,
        isTracking: true,
      );
    }
  }

  // ==========================================
  // Route-based simulation (~50 km/h on roads)
  // ==========================================

  void simulateAlongRoute(List<RoutePoint> points) {
    if (points.length < 2) return;
    _simTimer?.cancel();
    _simTimer = null;

    _routePoints = points;
    _simIndex = 0;
    _simProgress = 0;
    _simSegmentDist = _dist(
      points[0].latitude, points[0].longitude,
      points[1].latitude, points[1].longitude,
    );

    final heading = _bear(
      points[0].latitude, points[0].longitude,
      points[1].latitude, points[1].longitude,
    );

    state = state.copyWith(
      isSimulating: true,
      hasPermission: true,
      latitude: points[0].latitude,
      longitude: points[0].longitude,
      heading: heading,
      speedMps: _simSpeedMps,
      isTracking: true,
    );

    _simTimer = Timer.periodic(
      const Duration(milliseconds: _simTickMs),
      (_) => _tickRouteSim(),
    );
  }

  void _tickRouteSim() {
    if (!state.isSimulating || _routePoints.length < 2) return;

    final dt = _simTickMs / 1000.0;
    final metersThisTick = _simSpeedMps * dt;

    // How far along this segment (0..1)
    if (_simSegmentDist > 0) {
      _simProgress += metersThisTick / _simSegmentDist;
    } else {
      _simProgress = 1.0;
    }

    // Advance to next segment(s) if needed
    while (_simProgress >= 1.0 && _simIndex < _routePoints.length - 2) {
      _simProgress -= 1.0;
      _simIndex++;
      _simSegmentDist = _dist(
        _routePoints[_simIndex].latitude, _routePoints[_simIndex].longitude,
        _routePoints[_simIndex + 1].latitude, _routePoints[_simIndex + 1].longitude,
      );
      if (_simSegmentDist > 0) {
        _simProgress = (_simProgress * _simSegmentDist) / _simSegmentDist;
        // Keep overflow proportional
      }
    }

    // Reached end of route?
    if (_simIndex >= _routePoints.length - 2 && _simProgress >= 1.0) {
      final last = _routePoints.last;
      state = state.copyWith(
        latitude: last.latitude,
        longitude: last.longitude,
        speedMps: 0,
      );
      stopSimulation();
      onSimulationFinished?.call();
      return;
    }

    // Interpolate position
    final from = _routePoints[_simIndex];
    final to = _routePoints[_simIndex + 1];
    final t = _simProgress.clamp(0.0, 1.0);
    final lat = from.latitude + (to.latitude - from.latitude) * t;
    final lng = from.longitude + (to.longitude - from.longitude) * t;

    // Smooth heading
    final targetHeading = _bear(from.latitude, from.longitude, to.latitude, to.longitude);
    final currentHeading = state.heading;
    var diff = targetHeading - currentHeading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final heading = (currentHeading + diff * 0.2) % 360;

    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      heading: heading,
      speedMps: _simSpeedMps,
    );
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _routePoints = [];
    state = state.copyWith(isSimulating: false, speedMps: 0);
  }

  // ==========================================
  // Utilities
  // ==========================================

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLa = (lat2 - lat1) * pi / 180;
    final dLo = (lng2 - lng1) * pi / 180;
    final a = sin(dLa / 2) * sin(dLa / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLo / 2) * sin(dLo / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _bear(double lat1, double lng1, double lat2, double lng2) {
    final dL = (lng2 - lng1) * pi / 180;
    final y = sin(dL) * cos(lat2 * pi / 180);
    final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dL);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> openSettings() async => await Geolocator.openAppSettings();

  @override
  void dispose() {
    _positionSub?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
