import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/directions_service.dart';
import '../data/geocoding_service.dart';
import '../domain/place_model.dart';
import '../domain/route_model.dart';
import 'location_provider.dart';

enum NavMode { idle, searching, routePreview, navigating, driving }

/// Which field is being searched: origin or destination
enum SearchTarget { origin, destination }

class NavState {
  final NavMode mode;
  final Place? origin;
  final Place? destination;
  final RouteInfo? route;
  final int currentStepIndex;
  final bool isLoading;
  final String? error;
  final SearchTarget searchTarget;

  // Search
  final List<Place> searchResults;
  final bool isSearching;

  const NavState({
    this.mode = NavMode.idle,
    this.origin,
    this.destination,
    this.route,
    this.currentStepIndex = 0,
    this.isLoading = false,
    this.error,
    this.searchTarget = SearchTarget.destination,
    this.searchResults = const [],
    this.isSearching = false,
  });

  bool get hasCustomOrigin => origin != null;

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
    int? currentStepIndex,
    bool? isLoading,
    String? error,
    SearchTarget? searchTarget,
    List<Place>? searchResults,
    bool? isSearching,
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
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchTarget: searchTarget ?? this.searchTarget,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
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
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final loc = _ref.read(locationProvider);
        final results = await _geocoding.search(
          query,
          lat: loc.latitude,
          lng: loc.longitude,
        );
        if (mounted) {
          state = state.copyWith(searchResults: results, isSearching: false);
        }
      } catch (e) {
        if (mounted) {
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

      final route = await _directions.getRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: place.latitude,
        destLng: place.longitude,
      );

      if (mounted) {
        state = state.copyWith(route: route, isLoading: false);
      }
    } catch (e) {
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

  void startNavigation() {
    if (state.route == null) return;
    state = state.copyWith(mode: NavMode.navigating, currentStepIndex: 0);

    _navUpdateTimer?.cancel();
    _navUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateCurrentStep();
    });
  }

  /// "Just drive" mode — windshield view, no destination
  void startDriving() {
    state = state.copyWith(mode: NavMode.driving);
  }

  void stopDriving() {
    state = const NavState();
  }

  void _updateCurrentStep() {
    final loc = _ref.read(locationProvider);
    if (!loc.hasLocation || state.route == null) return;

    final steps = state.route!.steps;
    if (state.currentStepIndex >= steps.length - 1) return;

    final nextIdx = state.currentStepIndex + 1;
    if (nextIdx < steps.length) {
      final nextStep = steps[nextIdx];
      final dist = _distanceMeters(
        loc.latitude!, loc.longitude!,
        nextStep.location.latitude, nextStep.location.longitude,
      );
      if (dist < 30) {
        state = state.copyWith(currentStepIndex: nextIdx);
      }
    }

    final dest = state.destination!;
    final distToDest = _distanceMeters(
      loc.latitude!, loc.longitude!,
      dest.latitude, dest.longitude,
    );
    if (distToDest < 50) {
      stopNavigation();
    }
  }

  void stopNavigation() {
    _navUpdateTimer?.cancel();
    state = const NavState();
  }

  void clearRoute() {
    _navUpdateTimer?.cancel();
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
