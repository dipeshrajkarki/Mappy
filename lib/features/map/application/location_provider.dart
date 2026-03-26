import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

// Denser simulated route around central Oslo for smoother driving
const _simulatedRoute = [
  (lat: 59.91390, lng: 10.75220),
  (lat: 59.91405, lng: 10.75260),
  (lat: 59.91420, lng: 10.75300),
  (lat: 59.91440, lng: 10.75340),
  (lat: 59.91460, lng: 10.75380),
  (lat: 59.91485, lng: 10.75420),
  (lat: 59.91510, lng: 10.75450),
  (lat: 59.91540, lng: 10.75480),
  (lat: 59.91570, lng: 10.75500),
  (lat: 59.91605, lng: 10.75510),
  (lat: 59.91640, lng: 10.75520),
  (lat: 59.91680, lng: 10.75540),
  (lat: 59.91720, lng: 10.75550),
  (lat: 59.91760, lng: 10.75540),
  (lat: 59.91800, lng: 10.75510),
  (lat: 59.91835, lng: 10.75470),
  (lat: 59.91865, lng: 10.75420),
  (lat: 59.91890, lng: 10.75370),
  (lat: 59.91920, lng: 10.75300),
  (lat: 59.91945, lng: 10.75230),
  (lat: 59.91970, lng: 10.75150),
  (lat: 59.91995, lng: 10.75070),
  (lat: 59.92020, lng: 10.74990),
  (lat: 59.92045, lng: 10.74900),
  (lat: 59.92070, lng: 10.74810),
  (lat: 59.92095, lng: 10.74720),
  (lat: 59.92115, lng: 10.74630),
  (lat: 59.92135, lng: 10.74540),
  (lat: 59.92155, lng: 10.74450),
  (lat: 59.92170, lng: 10.74350),
  (lat: 59.92180, lng: 10.74250),
  (lat: 59.92195, lng: 10.74150),
  (lat: 59.92200, lng: 10.74050),
  (lat: 59.92195, lng: 10.73950),
  (lat: 59.92180, lng: 10.73850),
  (lat: 59.92160, lng: 10.73760),
  (lat: 59.92130, lng: 10.73680),
  (lat: 59.92100, lng: 10.73610),
  (lat: 59.92060, lng: 10.73550),
  (lat: 59.92020, lng: 10.73500),
  (lat: 59.91980, lng: 10.73460),
  (lat: 59.91935, lng: 10.73430),
  (lat: 59.91890, lng: 10.73410),
  (lat: 59.91845, lng: 10.73400),
  (lat: 59.91800, lng: 10.73410),
  (lat: 59.91755, lng: 10.73430),
  (lat: 59.91710, lng: 10.73460),
  (lat: 59.91670, lng: 10.73500),
  (lat: 59.91635, lng: 10.73550),
  (lat: 59.91600, lng: 10.73610),
  (lat: 59.91570, lng: 10.73680),
  (lat: 59.91545, lng: 10.73760),
  (lat: 59.91520, lng: 10.73850),
  (lat: 59.91500, lng: 10.73950),
  (lat: 59.91485, lng: 10.74050),
  (lat: 59.91475, lng: 10.74150),
  (lat: 59.91465, lng: 10.74260),
  (lat: 59.91455, lng: 10.74370),
  (lat: 59.91445, lng: 10.74480),
  (lat: 59.91430, lng: 10.74590),
  (lat: 59.91415, lng: 10.74700),
  (lat: 59.91400, lng: 10.74810),
  (lat: 59.91385, lng: 10.74920),
  (lat: 59.91370, lng: 10.75030),
  (lat: 59.91370, lng: 10.75100),
  (lat: 59.91375, lng: 10.75170),
  (lat: 59.91385, lng: 10.75220),
  (lat: 59.91390, lng: 10.75220),
];

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  StreamSubscription<Position>? _positionSub;
  Timer? _simTimer;
  int _simIndex = 0;

  // Interpolation state
  double _fromLat = 0, _fromLng = 0;
  double _toLat = 0, _toLng = 0;
  double _targetHeading = 0;
  double _targetSpeed = 0;
  int _interpStep = 0;
  static const _interpSteps = 20; // sub-steps per segment
  static const _segmentMs = 600; // ms per route segment

  Future<void> init() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        error: 'Location services are disabled. Please enable GPS.',
      );
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
        error: 'Location permission permanently denied. Tap to open settings.',
        permissionDeniedForever: true,
      );
      return;
    }

    state = state.copyWith(hasPermission: true, clearError: true);
    _startTracking();
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        if (!state.isSimulating) {
          state = state.copyWith(
            latitude: position.latitude,
            longitude: position.longitude,
            speedMps: position.speed,
            heading: position.heading,
            isTracking: true,
          );
        }
      },
      onError: (error) {
        state = state.copyWith(error: 'Location error: $error');
      },
    );
  }

  void toggleSimulation() {
    if (state.isSimulating) {
      stopSimulation();
    } else {
      startSimulation();
    }
  }

  void startSimulation() {
    _simTimer?.cancel();
    _simIndex = 0;
    _interpStep = 0;

    final first = _simulatedRoute[0];
    _fromLat = first.lat;
    _fromLng = first.lng;
    _toLat = _simulatedRoute[1].lat;
    _toLng = _simulatedRoute[1].lng;
    _targetHeading = _bearing(_fromLat, _fromLng, _toLat, _toLng);
    final dist = _distance(_fromLat, _fromLng, _toLat, _toLng);
    _targetSpeed = dist / (_segmentMs / 1000);

    state = state.copyWith(
      isSimulating: true,
      hasPermission: true,
      latitude: first.lat,
      longitude: first.lng,
      heading: _targetHeading,
      speedMps: _targetSpeed,
      isTracking: true,
    );

    // Smooth interpolation timer: ~30fps
    final intervalMs = _segmentMs ~/ _interpSteps;
    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _advanceInterpolation();
    });
  }

  void _advanceInterpolation() {
    _interpStep++;

    if (_interpStep >= _interpSteps) {
      // Move to next segment
      _interpStep = 0;
      _simIndex = (_simIndex + 1) % _simulatedRoute.length;
      final nextIndex = (_simIndex + 1) % _simulatedRoute.length;

      final current = _simulatedRoute[_simIndex];
      final next = _simulatedRoute[nextIndex];

      _fromLat = current.lat;
      _fromLng = current.lng;
      _toLat = next.lat;
      _toLng = next.lng;
      _targetHeading = _bearing(_fromLat, _fromLng, _toLat, _toLng);
      final dist = _distance(_fromLat, _fromLng, _toLat, _toLng);
      _targetSpeed = dist / (_segmentMs / 1000);
    }

    // Lerp position
    final t = _interpStep / _interpSteps;
    final lat = _fromLat + (_toLat - _fromLat) * t;
    final lng = _fromLng + (_toLng - _fromLng) * t;

    // Smooth heading (lerp towards target)
    final currentHeading = state.heading;
    var headingDiff = _targetHeading - currentHeading;
    if (headingDiff > 180) headingDiff -= 360;
    if (headingDiff < -180) headingDiff += 360;
    final smoothHeading = currentHeading + headingDiff * 0.15;

    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      heading: smoothHeading % 360,
      speedMps: _targetSpeed,
      isTracking: true,
    );
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    state = state.copyWith(isSimulating: false, speedMps: 0);
  }

  static double _distance(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _rad(lng2 - lng1);
    final y = sin(dLng) * cos(_rad(lat2));
    final x =
        cos(_rad(lat1)) * sin(_rad(lat2)) - sin(_rad(lat1)) * cos(_rad(lat2)) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double _rad(double deg) => deg * pi / 180;

  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

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
