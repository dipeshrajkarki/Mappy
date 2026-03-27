import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../data/directions_service.dart';
import '../data/geocoding_service.dart';
import '../domain/place_model.dart';
import '../domain/route_model.dart';
import 'location_provider.dart';

enum NavMode { idle, searching, routePreview, navigating, arriving }

/// Which field is being searched: origin or destination
enum SearchTarget { origin, destination }

class NavState {
  final NavMode mode;
  final Place? origin;
  final Place? destination;
  final RouteInfo? route;
  final List<RouteInfo> alternativeRoutes;
  final int currentStepIndex;
  final bool isLoading;
  final String? error;
  final SearchTarget searchTarget;
  final RoutingProfile currentProfile;

  // Search
  final List<Place> searchResults;
  final bool isSearching;
  final bool gpsLost;

  // Live navigation progress
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;

  const NavState({
    this.mode = NavMode.idle,
    this.origin,
    this.destination,
    this.route,
    this.alternativeRoutes = const [],
    this.currentStepIndex = 0,
    this.isLoading = false,
    this.error,
    this.searchTarget = SearchTarget.destination,
    this.currentProfile = RoutingProfile.drivingTraffic,
    this.searchResults = const [],
    this.isSearching = false,
    this.gpsLost = false,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
  });

  bool get hasCustomOrigin => origin != null;

  String get remainingDistanceText {
    if (remainingDistanceMeters >= 1000) {
      return '${(remainingDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${remainingDistanceMeters.round()} m';
  }

  String get remainingDurationText {
    final totalMin = (remainingDurationSeconds / 60).round();
    if (totalMin < 60) return '$totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return '${h}h ${m}m';
  }

  String get remainingEtaText {
    final arrival = DateTime.now().add(Duration(seconds: remainingDurationSeconds.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  RouteStep? get currentStep {
    if (route == null || currentStepIndex >= route!.steps.length) return null;
    return route!.steps[currentStepIndex];
  }

  RouteStep? get nextStep {
    if (route == null || currentStepIndex + 1 >= route!.steps.length) return null;
    return route!.steps[currentStepIndex + 1];
  }

  NavState copyWith({
    NavMode? mode,
    Place? origin,
    Place? destination,
    RouteInfo? route,
    List<RouteInfo>? alternativeRoutes,
    int? currentStepIndex,
    bool? isLoading,
    String? error,
    SearchTarget? searchTarget,
    RoutingProfile? currentProfile,
    List<Place>? searchResults,
    bool? isSearching,
    bool? gpsLost,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
    bool clearError = false,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearRoute = false,
  }) {
    return NavState(
      mode: mode ?? this.mode,
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      route: clearRoute ? null : (route ?? this.route),
      alternativeRoutes: clearRoute ? const [] : (alternativeRoutes ?? this.alternativeRoutes),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchTarget: searchTarget ?? this.searchTarget,
      currentProfile: currentProfile ?? this.currentProfile,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      gpsLost: gpsLost ?? this.gpsLost,
      remainingDistanceMeters: remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds: remainingDurationSeconds ?? this.remainingDurationSeconds,
    );
  }
}

class NavNotifier extends StateNotifier<NavState> {
  NavNotifier(this._ref) : super(const NavState());

  final Ref _ref;
  final _geocoding = GeocodingService();
  final _directions = DirectionsService();
  Timer? _searchDebounce;
  Timer? _navUpdateTimer;
  int _searchGeneration = 0; // tracks latest search to discard stale results

  void openSearch({SearchTarget target = SearchTarget.destination}) {
    state = state.copyWith(
      mode: NavMode.searching,
      searchTarget: target,
      searchResults: [],
    );
  }

  void closeSearch() {
    _searchDebounce?.cancel();
    state = state.copyWith(mode: NavMode.idle, searchResults: [], isSearching: false);
  }

  void search(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true);
    final generation = ++_searchGeneration;
    _searchDebounce = Timer(const Duration(milliseconds: AppConstants.searchDebounceMs), () async {
      try {
        final loc = _ref.read(locationProvider);
        final results = await _geocoding.search(
          query,
          lat: loc.latitude,
          lng: loc.longitude,
        );
        // Only apply if this is still the latest search
        if (mounted && generation == _searchGeneration) {
          state = state.copyWith(searchResults: results, isSearching: false);
        }
      } catch (e) {
        debugPrint('Search error: $e');
        if (mounted && generation == _searchGeneration) {
          state = state.copyWith(isSearching: false);
        }
      }
    });
  }

  void selectSearchResult(Place place) {
    if (state.searchTarget == SearchTarget.origin) {
      state = state.copyWith(
        origin: place,
        mode: NavMode.idle,
        searchResults: [],
        isSearching: false,
      );
    } else {
      selectDestination(place);
    }
  }

  void clearOrigin() {
    state = state.copyWith(clearOrigin: true);
  }

  Future<void> selectDestination(Place place) async {
    state = state.copyWith(
      mode: NavMode.routePreview,
      destination: place,
      isLoading: true,
      clearError: true,
      searchResults: [],
    );

    try {
      double originLat, originLng;

      if (state.hasCustomOrigin) {
        originLat = state.origin!.latitude;
        originLng = state.origin!.longitude;
      } else {
        final loc = _ref.read(locationProvider);
        if (!loc.hasLocation) {
          state = state.copyWith(
            error: 'Waiting for GPS location...',
            isLoading: false,
          );
          return;
        }
        originLat = loc.latitude!;
        originLng = loc.longitude!;
      }

      final routes = await _directions.getRoutes(
        originLat: originLat,
        originLng: originLng,
        destLat: place.latitude,
        destLng: place.longitude,
        profile: state.currentProfile,
      );

      if (mounted) {
        state = state.copyWith(
          route: routes.first,
          alternativeRoutes: routes.length > 1 ? routes.sublist(1) : const [],
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
      if (mounted) {
        state = state.copyWith(
          error: 'Could not find route. Try again.',
          isLoading: false,
          mode: NavMode.idle,
          clearDestination: true,
          clearRoute: true,
        );
      }
    }
  }

  void selectAlternativeRoute(int index) {
    if (index < 0 || index >= state.alternativeRoutes.length) return;
    if (state.route == null) return;
    final selected = state.alternativeRoutes[index];
    // Put current route back into alternatives, remove the selected one
    final newAlts = <RouteInfo>[
      state.route!,
      ...state.alternativeRoutes.where((r) => r != selected),
    ];
    state = state.copyWith(
      route: selected,
      alternativeRoutes: newAlts,
    );
  }

  void setRoutingProfile(RoutingProfile profile) {
    if (state.currentProfile == profile) return;
    state = state.copyWith(
      currentProfile: profile,
      alternativeRoutes: const [], // clear stale alternatives while loading
    );
    if (state.destination != null) {
      selectDestination(state.destination!);
    }
  }

  void startNavigation() {
    if (state.route == null) return;
    state = state.copyWith(
      mode: NavMode.navigating,
      currentStepIndex: 0,
      remainingDistanceMeters: state.route!.distanceMeters,
      remainingDurationSeconds: state.route!.durationSeconds,
    );

    // Enable road snapping for real GPS navigation
    _ref.read(locationProvider.notifier).setSnapToRoad(true);

    _navUpdateTimer?.cancel();
    _navUpdateTimer = Timer.periodic(const Duration(seconds: AppConstants.navUpdateIntervalSec), (_) {
      _updateCurrentStep();
    });
  }

  /// Start navigation with simulated driving along the route
  void startSimulatedNavigation() {
    if (state.route == null) return;
    state = state.copyWith(
      mode: NavMode.navigating,
      currentStepIndex: 0,
      remainingDistanceMeters: state.route!.distanceMeters,
      remainingDurationSeconds: state.route!.durationSeconds,
    );

    // Drive the car along the route geometry
    final locNotifier = _ref.read(locationProvider.notifier);
    locNotifier.onSimulationFinished = () {
      if (mounted) _arriveAtDestination();
    };
    locNotifier.simulateAlongRoute(state.route!.points);

    _navUpdateTimer?.cancel();
    _navUpdateTimer = Timer.periodic(const Duration(seconds: AppConstants.navUpdateIntervalSec), (_) {
      _updateCurrentStep();
    });
  }

  void _updateCurrentStep() {
    final loc = _ref.read(locationProvider);
    if (state.route == null) return;

    // Detect GPS loss during navigation
    if (!loc.hasLocation) {
      if (!state.gpsLost) {
        state = state.copyWith(gpsLost: true);
      }
      return;
    }
    // GPS recovered
    if (state.gpsLost) {
      state = state.copyWith(gpsLost: false);
    }

    final steps = state.route!.steps;
    if (state.currentStepIndex >= steps.length - 1) return;

    final nextIdx = state.currentStepIndex + 1;
    if (nextIdx < steps.length) {
      final nextStep = steps[nextIdx];
      final dist = _distanceMeters(
        loc.latitude!, loc.longitude!,
        nextStep.location.latitude, nextStep.location.longitude,
      );
      if (dist < AppConstants.stepDetectionMeters) {
        state = state.copyWith(currentStepIndex: nextIdx);
      }
    }

    // Update remaining distance and ETA
    _updateRemainingProgress(loc.latitude!, loc.longitude!);

    final dest = state.destination;
    if (dest == null) return;
    final distToDest = _distanceMeters(
      loc.latitude!, loc.longitude!,
      dest.latitude, dest.longitude,
    );
    if (distToDest < AppConstants.destinationDetectionMeters) {
      _arriveAtDestination();
    }
  }

  void _updateRemainingProgress(double lat, double lng) {
    final route = state.route;
    if (route == null) return;

    // Sum distance/duration of remaining steps from current step onward
    final steps = route.steps;
    double remainDist = 0;
    double remainDur = 0;
    for (int i = state.currentStepIndex; i < steps.length; i++) {
      remainDist += steps[i].distanceMeters;
      remainDur += steps[i].durationSeconds;
    }

    // Subtract progress within current step (approximate by distance to next step location)
    if (state.currentStepIndex < steps.length) {
      final currentStep = steps[state.currentStepIndex];
      final distToStepEnd = _distanceMeters(
        lat, lng,
        currentStep.location.latitude, currentStep.location.longitude,
      );
      // Current step's distance minus how far we are into it
      final progress = currentStep.distanceMeters > 0
          ? (1.0 - (distToStepEnd / currentStep.distanceMeters).clamp(0.0, 1.0))
          : 1.0;
      remainDist -= currentStep.distanceMeters * progress;
      remainDur -= currentStep.durationSeconds * progress;
    }

    state = state.copyWith(
      remainingDistanceMeters: remainDist.clamp(0, double.infinity),
      remainingDurationSeconds: remainDur.clamp(0, double.infinity),
    );
  }

  void _arriveAtDestination() {
    _navUpdateTimer?.cancel();
    _ref.read(locationProvider.notifier).stopSimulation();
    state = state.copyWith(mode: NavMode.arriving);
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && state.mode == NavMode.arriving) {
        _fullStop();
      }
    });
  }

  void stopNavigation() {
    _fullStop();
  }

  void clearRoute() {
    _navUpdateTimer?.cancel();
    state = const NavState();
  }

  /// Fully stop navigation + simulation + snap-to-road
  void _fullStop() {
    _navUpdateTimer?.cancel();
    _navUpdateTimer = null;
    final locNotifier = _ref.read(locationProvider.notifier);
    locNotifier.onSimulationFinished = null; // clear stale callback
    locNotifier.stopSimulation();
    locNotifier.setSnapToRoad(false);
    state = const NavState();
  }

  static double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _navUpdateTimer?.cancel();
    super.dispose();
  }
}

final navProvider = StateNotifierProvider<NavNotifier, NavState>((ref) {
  return NavNotifier(ref);
});
