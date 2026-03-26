import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../application/location_provider.dart';
import '../application/navigation_provider.dart';
import '../domain/route_model.dart';
import 'widgets/search_sheet.dart';
import 'widgets/route_preview_panel.dart';
import 'widgets/navigation_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  bool _isFollowing = true;
  bool _northUp = false; // false = heading-up in drive mode, true = north-up
  PolylineAnnotationManager? _routeLineManager;
  PointAnnotationManager? _markerManager;
  PointAnnotationManager? _navArrowManager;
  PointAnnotation? _navArrow;
  Uint8List? _arrowImageBytes;
  Uint8List? _customCarBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).init();
      _loadIcons();
    });
  }

  Future<void> _loadIcons() async {
    // Generate default navigation arrow
    _arrowImageBytes = await _generateArrowImage();

    // Try loading custom car icon from assets
    try {
      final data = await rootBundle.load('assets/icons/car.png');
      _customCarBytes = data.buffer.asUint8List();
    } catch (_) {
      // No custom car icon — will use the arrow
    }
  }

  /// Generates a lime navigation chevron/arrow image
  Future<Uint8List> _generateArrowImage() async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Draw arrow pointing up
    final paint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size / 2, 8) // top point
      ..lineTo(size - 14, size - 12) // bottom right
      ..lineTo(size / 2, size - 24) // notch
      ..lineTo(14, size - 12) // bottom left
      ..close();

    // Shadow
    canvas.save();
    canvas.translate(2, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Arrow
    canvas.drawPath(path, paint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Location puck — use default blue dot initially
    await _mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: AppTheme.accent.toARGB32(),
        showAccuracyRing: true,
      ),
    );

    await _mapboxMap!.scaleBar.updateSettings(
      ScaleBarSettings(enabled: false),
    );
    await _mapboxMap!.compass.updateSettings(
      CompassSettings(enabled: false),
    );

    _routeLineManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();
    _markerManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();
    _navArrowManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    _enable3DBuildings();
  }

  void _enable3DBuildings() async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.style.addLayer(FillExtrusionLayer(
        id: 'buildings-3d',
        sourceId: 'composite',
        sourceLayer: 'building',
        minZoom: 14,
        fillExtrusionColor: const Color(0xFF1A1A2E).toARGB32(),
        fillExtrusionHeightExpression: [
          'interpolate', ['linear'], ['zoom'],
          14, 0, 14.5, ['get', 'height'],
        ],
        fillExtrusionBaseExpression: ['get', 'min_height'],
        fillExtrusionOpacity: 0.7,
      ));
    } catch (_) {}
  }

  /// Update the navigation arrow marker position during simulation
  void _updateNavArrow(LocationState loc) async {
    if (_navArrowManager == null || !loc.hasLocation) return;

    final iconBytes = _customCarBytes ?? _arrowImageBytes;
    if (iconBytes == null) return;

    final point = Point(
      coordinates: Position(loc.longitude!, loc.latitude!),
    );

    if (_navArrow != null) {
      // Update existing arrow position and rotation
      _navArrow!.geometry = point;
      _navArrow!.iconRotate = loc.heading;
      await _navArrowManager!.update(_navArrow!);
    } else {
      // Create new arrow
      _navArrow = await _navArrowManager!.create(
        PointAnnotationOptions(
          geometry: point,
          image: iconBytes,
          iconSize: 0.6,
          iconRotate: loc.heading,
          iconAnchor: IconAnchor.CENTER,
          iconOffset: [0.0, 0.0],
        ),
      );
    }
  }

  void _removeNavArrow() async {
    if (_navArrow != null && _navArrowManager != null) {
      await _navArrowManager!.delete(_navArrow!);
      _navArrow = null;
    }
  }

  void _flyToUser() {
    final loc = ref.read(locationProvider);
    if (!loc.hasLocation) return;

    setState(() => _isFollowing = true);
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(loc.longitude!, loc.latitude!),
        ),
        zoom: AppConstants.navigationZoom,
        bearing: 0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _updateCameraSmooth(LocationState loc, NavMode mode) {
    if (!loc.hasLocation || _mapboxMap == null) return;

    final isDriveView = mode == NavMode.navigating || mode == NavMode.driving;

    double bearing = 0;
    double pitch = 0;
    double zoom = AppConstants.navigationZoom;

    if (isDriveView) {
      bearing = _northUp ? 0 : loc.heading;
      pitch = 65;
      zoom = 17.5;
    }

    _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(loc.longitude!, loc.latitude!),
        ),
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
      ),
      MapAnimationOptions(duration: 300),
    );
  }

  void _toggleNorthUp() {
    setState(() => _northUp = !_northUp);
    final loc = ref.read(locationProvider);
    final navState = ref.read(navProvider);
    _updateCameraSmooth(loc, navState.mode);
  }

  void _drawRoute(RouteInfo route) async {
    if (_routeLineManager == null) return;

    await _routeLineManager!.deleteAll();
    await _markerManager?.deleteAll();

    final coords = route.points
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    // Traffic-colored segments
    if (route.hasTrafficData && route.congestion.length >= coords.length - 1) {
      int i = 0;
      while (i < route.congestion.length && i < coords.length - 1) {
        final level = route.congestion[i];
        int j = i;
        while (j < route.congestion.length &&
            j < coords.length - 1 &&
            route.congestion[j] == level) {
          j++;
        }
        final segCoords = coords.sublist(i, j + 1);
        if (segCoords.length >= 2) {
          await _routeLineManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: segCoords),
              lineColor: _trafficColor(level),
              lineWidth: 6.0,
              lineOpacity: 1.0,
            ),
          );
        }
        i = j;
      }
    } else {
      await _routeLineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords),
          lineColor: AppTheme.routeGlow.toARGB32(),
          lineWidth: 14.0,
          lineOpacity: 0.3,
        ),
      );
      await _routeLineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords),
          lineColor: AppTheme.routeColor.toARGB32(),
          lineWidth: 5.0,
          lineOpacity: 1.0,
        ),
      );
    }

    // Start marker
    final start = route.points.first;
    await _markerManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(start.longitude, start.latitude)),
        textField: 'Start',
        textSize: 12,
        textColor: Colors.white.toARGB32(),
        textHaloColor: AppTheme.bgDark.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, -2.0],
        iconSize: 0.8,
      ),
    );

    // Destination marker
    final end = route.points.last;
    await _markerManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(end.longitude, end.latitude)),
        textField: 'Destination',
        textSize: 12,
        textColor: Colors.white.toARGB32(),
        textHaloColor: AppTheme.bgDark.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, -2.0],
        iconSize: 0.8,
      ),
    );

    _fitRouteBounds(route);
  }

  int _trafficColor(String level) {
    switch (level) {
      case 'severe':
        return const Color(0xFFE53935).toARGB32();
      case 'heavy':
        return const Color(0xFFFF8F00).toARGB32();
      case 'moderate':
        return const Color(0xFFFFD600).toARGB32();
      case 'low':
      case 'unknown':
      default:
        return AppTheme.routeColor.toARGB32();
    }
  }

  void _fitRouteBounds(RouteInfo route) {
    if (route.points.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in route.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapboxMap?.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 120, left: 60, bottom: 340, right: 60),
      null, null, null, null,
    ).then((camera) {
      _mapboxMap?.flyTo(camera, MapAnimationOptions(duration: 1000));
    });

    setState(() => _isFollowing = false);
  }

  void _clearRoute() async {
    await _routeLineManager?.deleteAll();
    await _markerManager?.deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final navState = ref.watch(navProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDriveMode = navState.mode == NavMode.navigating ||
        navState.mode == NavMode.driving;

    // Camera follow + nav arrow updates
    ref.listen<LocationState>(locationProvider, (prev, next) {
      // Update nav arrow during simulation or driving
      if (next.isSimulating || isDriveMode) {
        _updateNavArrow(next);
      }

      if (!_isFollowing || !next.hasLocation || _mapboxMap == null) return;
      if (navState.mode == NavMode.routePreview) return;

      _updateCameraSmooth(next, navState.mode);
    });

    // Mode changes
    ref.listen<NavState>(navProvider, (prev, next) {
      if (next.route != null && prev?.route != next.route) {
        _drawRoute(next.route!);
      }
      if (next.mode == NavMode.idle && prev?.mode != NavMode.idle) {
        _clearRoute();
        _removeNavArrow();
        _flyToUser();
      }
      if (next.mode == NavMode.navigating && prev?.mode != NavMode.navigating) {
        setState(() => _isFollowing = true);
      }
      if (next.mode == NavMode.driving && prev?.mode != NavMode.driving) {
        setState(() => _isFollowing = true);
      }
    });

    // Show/hide nav arrow based on simulation state
    ref.listen<LocationState>(locationProvider, (prev, next) {
      if (prev?.isSimulating == true && !next.isSimulating) {
        _removeNavArrow();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            // === MAP ===
            MapWidget(
              styleUri: AppConstants.mapboxStyleUrl,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    AppConstants.defaultLng,
                    AppConstants.defaultLat,
                  ),
                ),
                zoom: AppConstants.defaultZoom,
              ),
              onMapCreated: _onMapCreated,
              onScrollListener: (_) {
                if (_isFollowing) setState(() => _isFollowing = false);
              },
            ),

            // === TOP GRADIENT ===
            if (!isDriveMode)
              Positioned(
                top: 0, left: 0, right: 0,
                height: topPadding + 24,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.bgDark.withValues(alpha: 0.8),
                          AppTheme.bgDark.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // === IDLE STATE ===
            if (navState.mode == NavMode.idle) ...[
              Positioned(
                top: topPadding + 12,
                left: AppTheme.spacingLg,
                child: const Text(
                  'Your Trip',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 12,
                right: AppTheme.spacingMd,
                child: _DarkButton(
                  icon: Icons.my_location,
                  onTap: _flyToUser,
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _WhereToPanel(
                  isSimulating: locationState.isSimulating,
                  customOrigin: navState.origin,
                  onOriginTap: () => ref.read(navProvider.notifier)
                      .openSearch(target: SearchTarget.origin),
                  onClearOrigin: () => ref.read(navProvider.notifier).clearOrigin(),
                  onSearchTap: () => ref.read(navProvider.notifier).openSearch(),
                  onSimToggle: () {
                    ref.read(locationProvider.notifier).toggleSimulation();
                    setState(() => _isFollowing = true);
                  },
                  onJustDrive: () {
                    ref.read(navProvider.notifier).startDriving();
                    setState(() => _isFollowing = true);
                  },
                ),
              ),
            ],

            // === SEARCHING ===
            if (navState.mode == NavMode.searching)
              SearchSheet(
                results: navState.searchResults,
                isSearching: navState.isSearching,
                hintText: navState.searchTarget == SearchTarget.origin
                    ? 'Search starting point'
                    : 'Search destination',
                onSearch: (q) => ref.read(navProvider.notifier).search(q),
                onSelect: (place) =>
                    ref.read(navProvider.notifier).selectSearchResult(place),
                onClose: () => ref.read(navProvider.notifier).closeSearch(),
              ),

            // === ROUTE PREVIEW ===
            if (navState.mode == NavMode.routePreview) ...[
              Positioned(
                top: topPadding + 12,
                right: AppTheme.spacingMd,
                child: _DarkButton(
                  icon: Icons.my_location,
                  onTap: _flyToUser,
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: RoutePreviewPanel(
                  destination: navState.destination!,
                  route: navState.route,
                  isLoading: navState.isLoading,
                  onStart: () =>
                      ref.read(navProvider.notifier).startNavigation(),
                  onClose: () => ref.read(navProvider.notifier).clearRoute(),
                ),
              ),
            ],

            // === NAVIGATING ===
            if (navState.mode == NavMode.navigating) ...[
              Positioned(
                top: 0, left: 0, right: 0,
                child: NavigationTopBar(
                  currentStep: navState.currentStep,
                  nextStep: navState.nextStep,
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: NavigationBottomBar(
                  route: navState.route!,
                  onStop: () => ref.read(navProvider.notifier).stopNavigation(),
                ),
              ),
            ],

            // === DRIVING MODE ===
            if (navState.mode == NavMode.driving)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _DrivingBar(
                  onStop: () => ref.read(navProvider.notifier).stopDriving(),
                ),
              ),

            // === Right-side buttons (nav/drive) ===
            if (isDriveMode)
              Positioned(
                bottom: bottomPadding + 120,
                right: AppTheme.spacingMd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // North-up / heading-up toggle
                    _DarkButton(
                      icon: _northUp ? Icons.navigation : Icons.explore,
                      onTap: _toggleNorthUp,
                    ),
                    const SizedBox(height: 10),
                    // Re-center
                    _DarkButton(
                      icon: _isFollowing
                          ? Icons.my_location
                          : Icons.location_searching,
                      onTap: () {
                        setState(() => _isFollowing = true);
                        final loc = ref.read(locationProvider);
                        _updateCameraSmooth(loc, navState.mode);
                      },
                    ),
                  ],
                ),
              ),

            // === LOADING ===
            if (navState.isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),

            // === ERROR ===
            if (locationState.error != null && navState.mode == NavMode.idle)
              Positioned(
                top: topPadding + 56,
                left: AppTheme.spacingMd,
                right: AppTheme.spacingMd,
                child: _ErrorBanner(
                  message: locationState.error!,
                  showSettingsButton: locationState.permissionDeniedForever,
                  onOpenSettings: () =>
                      ref.read(locationProvider.notifier).openSettings(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// === Bottom panel with From/To fields + actions ===

class _WhereToPanel extends StatelessWidget {
  final bool isSimulating;
  final dynamic customOrigin;
  final VoidCallback onOriginTap;
  final VoidCallback onClearOrigin;
  final VoidCallback onSearchTap;
  final VoidCallback onSimToggle;
  final VoidCallback onJustDrive;

  const _WhereToPanel({
    required this.isSimulating,
    this.customOrigin,
    required this.onOriginTap,
    required this.onClearOrigin,
    required this.onSearchTap,
    required this.onSimToggle,
    required this.onJustDrive,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 16),
            child: Column(
              children: [
                // FROM field
                GestureDetector(
                  onTap: onOriginTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            customOrigin != null
                                ? (customOrigin as dynamic).name as String
                                : 'My location',
                            style: TextStyle(
                              color: customOrigin != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (customOrigin != null)
                          GestureDetector(
                            onTap: onClearOrigin,
                            child: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                          )
                        else
                          const Icon(Icons.my_location, color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // TO field
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: AppTheme.accent, size: 18),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Where to?',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onJustDrive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.bgSurface),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.drive_eta, color: AppTheme.textPrimary, size: 18),
                              SizedBox(width: 8),
                              Text('Just drive',
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onSimToggle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSimulating ? AppTheme.error : AppTheme.accent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: isSimulating ? [] : AppTheme.glowShadow,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSimulating ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: isSimulating ? Colors.white : AppTheme.bgDark, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                isSimulating ? 'Stop sim' : 'Simulate',
                                style: TextStyle(
                                  color: isSimulating ? Colors.white : AppTheme.bgDark,
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === Driving mode bottom bar ===

class _DrivingBar extends ConsumerWidget {
  final VoidCallback onStop;
  const _DrivingBar({required this.onStop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final loc = ref.watch(locationProvider);
    final speedKmh = loc.speedKmh.round();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 20),
        child: Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$speedKmh',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary, height: 1)),
                  const SizedBox(height: 2),
                  const Text('km/h',
                    style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Driving',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Free driving mode',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Text('End',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Dark circular button ===

class _DarkButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DarkButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.bgSurface, width: 1),
          boxShadow: AppTheme.softShadow,
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }
}

// === Error banner ===

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool showSettingsButton;
  final VoidCallback onOpenSettings;

  const _ErrorBanner({
    required this.message,
    this.showSettingsButton = false,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: AppTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          if (showSettingsButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onOpenSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text('Settings',
                  style: TextStyle(color: AppTheme.bgDark, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
