import 'dart:math';
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
import 'widgets/drive_pad.dart';

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
  PointAnnotationManager? _pointManager;
  PointAnnotation? _pointAnnotation;
  Uint8List? _arrowImageBytes;
  Uint8List? _customCarBytes;
  String _selectedVehicle = 'sedan'; // 3D model from assets/models/
  
  final List<String> _availableVehicles = [
    'classic', 'sedan', 'suv', 'taxi', 'truck',
  ];

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

  /// Generates a bold, visible navigation arrow
  Future<Uint8List> _generateArrowImage() async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowPath = Path()
      ..moveTo(size / 2, 14)
      ..lineTo(size - 18, size - 14)
      ..lineTo(size / 2, size - 30)
      ..lineTo(18, size - 14)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Lime arrow body
    final paint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size / 2, 10)
      ..lineTo(size - 20, size - 16)
      ..lineTo(size / 2, size - 32)
      ..lineTo(20, size - 16)
      ..close();
    canvas.drawPath(path, paint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

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
    _pointManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    // Load initial model if 3D
    await _ensureModelLoaded(_selectedVehicle);
    
    _enable3DBuildings();
  }

  final Set<String> _loadedModels = {};

  Future<void> _ensureModelLoaded(String modelName) async {
    if (modelName == 'classic' || _mapboxMap == null) return;
    if (_loadedModels.contains(modelName)) return;
    
    try {
      await _mapboxMap!.style.addStyleModel(modelName, 'asset://assets/models/$modelName.glb');
      _loadedModels.add(modelName);
    } catch (_) {}
  }

  void _setNativePuckVisible(bool visible) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: visible,
        pulsingEnabled: visible,
        showAccuracyRing: visible,
      ),
    );
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



  bool _arrowActive = false;

  void _activateArrow() {
    if (!_arrowActive) {
      _arrowActive = true;
      _setNativePuckVisible(false);
    }
  }

  void _deactivateArrow() {
    if (_arrowActive) {
      _arrowActive = false;
      _clearAnnotations();
      _setNativePuckVisible(true);
    }
  }

  void _clearAnnotations() async {
    if (_pointAnnotation != null) {
      try {
        await _pointManager?.delete(_pointAnnotation!);
      } catch (_) {}
      _pointAnnotation = null;
    }
    _remove3DLayer();
  }

  bool _updatingArrow = false;
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';

  void _updateNavArrow(LocationState loc) async {
    if (!loc.hasLocation || _updatingArrow || _mapboxMap == null) return;
    _updatingArrow = true;
    _activateArrow();

    try {
      if (_selectedVehicle == 'classic') {
        await _update2DArrow(loc);
      } else {
        await _update3DModel(loc);
      }
    } catch (_) {}
    _updatingArrow = false;
  }

  Future<void> _update2DArrow(LocationState loc) async {
    if (_pointManager == null) return;

    // Remove 3D layer if switching from 3D
    _remove3DLayer();

    final point = Point(coordinates: Position(loc.longitude!, loc.latitude!));
    final iconBytes = _customCarBytes ?? _arrowImageBytes;
    if (iconBytes == null) return;

    if (_pointAnnotation != null) {
      try {
        _pointAnnotation!.geometry = point;
        _pointAnnotation!.iconRotate = loc.heading;
        await _pointManager!.update(_pointAnnotation!);
      } catch (_) {
        _pointAnnotation = null;
        _pointAnnotation = await _pointManager!.create(
          PointAnnotationOptions(
            geometry: point,
            image: iconBytes,
            iconSize: 0.35,
            iconRotate: loc.heading,
            iconAnchor: IconAnchor.CENTER,
          ),
        );
      }
    } else {
      _pointAnnotation = await _pointManager!.create(
        PointAnnotationOptions(
          geometry: point,
          image: iconBytes,
          iconSize: 0.35,
          iconRotate: loc.heading,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    }
  }

  Future<void> _update3DModel(LocationState loc) async {
    // Remove 2D arrow if switching from classic
    if (_pointAnnotation != null) {
      try {
        await _pointManager?.delete(_pointAnnotation!);
      } catch (_) {}
      _pointAnnotation = null;
    }

    final geojson =
        '{"type":"Feature","geometry":{"type":"Point","coordinates":[${loc.longitude},${loc.latitude}]}}';

    try {
      final sourceExists = await _mapboxMap!.style.styleSourceExists(_carSourceId);
      if (sourceExists) {
        // Update position
        final src = await _mapboxMap!.style.getSource(_carSourceId);
        (src as GeoJsonSource).updateGeoJSON(geojson);
        // Update rotation
        if (await _mapboxMap!.style.styleLayerExists(_carLayerId)) {
          await _mapboxMap!.style.setStyleLayerProperty(
            _carLayerId, 'model-rotation', [0.0, 0.0, loc.heading],
          );
        }
      } else {
        // Create source + layer
        await _mapboxMap!.style.addSource(
          GeoJsonSource(id: _carSourceId, data: geojson),
        );
        await _mapboxMap!.style.addLayer(ModelLayer(
          id: _carLayerId,
          sourceId: _carSourceId,
          modelId: _selectedVehicle,
          modelScale: [15.0, 15.0, 15.0],
          modelRotation: [0.0, 0.0, loc.heading],
          modelScaleMode: ModelScaleMode.MAP,
        ));
      }
    } catch (_) {}
  }

  void _remove3DLayer() async {
    try {
      if (await _mapboxMap!.style.styleLayerExists(_carLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_carLayerId);
      }
      if (await _mapboxMap!.style.styleSourceExists(_carSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_carSourceId);
      }
    } catch (_) {}
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
    final isWindshield = isDriveView || loc.isFakeGps || _selectedVehicle != 'classic';

    double bearing = 0;
    double pitch = 0;
    double zoom = AppConstants.navigationZoom;
    double centerLat = loc.latitude!;
    double centerLng = loc.longitude!;

    if (isWindshield) {
      bearing = _northUp ? 0 : loc.heading;
      pitch = 55;
      zoom = 17.5;

      // Offset camera center slightly BEHIND the car
      // so the car appears in the lower third and you see road ahead
      // Move ~40 meters behind the heading direction
      const offsetMeters = 40.0;
      final reverseHeading = (loc.heading + 180) % 360;
      final offset = _offsetLatLng(
        loc.latitude!, loc.longitude!, reverseHeading, offsetMeters,
      );
      centerLat = offset.$1;
      centerLng = offset.$2;
    }

    final duration = isWindshield ? 500 : 800;

    _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(centerLng, centerLat),
        ),
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
      ),
      MapAnimationOptions(duration: duration),
    );
  }

  /// Offset a lat/lng by [meters] in [bearing] degrees
  static (double, double) _offsetLatLng(
      double lat, double lng, double bearing, double meters) {
    const r = 6371000.0;
    final d = meters / r;
    final brng = bearing * pi / 180;
    final lat1 = lat * pi / 180;
    final lng1 = lng * pi / 180;
    final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng));
    final lng2 = lng1 +
        atan2(sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2));
    return (lat2 * 180 / pi, lng2 * 180 / pi);
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

  void _setVehicle(String vehicleType) async {
    await _ensureModelLoaded(vehicleType);
    setState(() => _selectedVehicle = vehicleType);
    _clearAnnotations();
    final loc = ref.read(locationProvider);
    if (_arrowActive) {
      _updateNavArrow(loc); // Redraw immediately with new model
    }
    _updateCameraSmooth(loc, ref.read(navProvider).mode);
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showCarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Vehicle Model',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '3D models (.glb/.gltf) can be added to the assets folder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _availableVehicles[index];
                    final isClassic = vehicle == 'classic';
                    final isSelected = vehicle == _selectedVehicle;

                    return ListTile(
                      leading: Icon(
                        isClassic ? Icons.navigation : Icons.directions_car,
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      title: Text(
                        isClassic ? 'Classic Arrow' : '3D $vehicle (.glb)',
                        style: TextStyle(
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.accent) : null,
                      onTap: () => _setVehicle(vehicle),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final navState = ref.watch(navProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDriveMode = navState.mode == NavMode.navigating ||
        navState.mode == NavMode.driving;

    // Location updates — arrow + camera in sync
    ref.listen<LocationState>(locationProvider, (prev, next) {
      final shouldShowArrow = next.isFakeGps || isDriveMode || _selectedVehicle != 'classic';

      if (shouldShowArrow && next.hasLocation) {
        _updateNavArrow(next);
      } else if (!shouldShowArrow && _arrowActive) {
        _deactivateArrow();
      }

      if (!_isFollowing || !next.hasLocation || _mapboxMap == null) return;
      if (navState.mode == NavMode.routePreview) return;

      _updateCameraSmooth(next, navState.mode);
    });

    // Nav state changes
    ref.listen<NavState>(navProvider, (prev, next) {
      if (next.route != null && prev?.route != next.route) {
        _drawRoute(next.route!);
      }
      if (next.mode == NavMode.idle && prev?.mode != NavMode.idle) {
        _clearRoute();
        _flyToUser();
      }
      if (next.mode == NavMode.navigating && prev?.mode != NavMode.navigating) {
        setState(() => _isFollowing = true);
      }
      if (next.mode == NavMode.driving && prev?.mode != NavMode.driving) {
        setState(() => _isFollowing = true);
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
                // Don't disable following during simulation/navigation
                final loc = ref.read(locationProvider);
                final nav = ref.read(navProvider);
                if (loc.isFakeGps ||
                    nav.mode == NavMode.navigating ||
                    nav.mode == NavMode.driving) return;
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
                child: Column(
                  children: [
                    _DarkButton(
                      icon: Icons.directions_car,
                      onTap: () => _showCarSelector(context),
                    ),
                    const SizedBox(height: 10),
                    _DarkButton(
                      icon: Icons.my_location,
                      onTap: _flyToUser,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _WhereToPanel(
                  isManualDriving: locationState.isManualDriving,
                  customOrigin: navState.origin,
                  onOriginTap: () => ref.read(navProvider.notifier)
                      .openSearch(target: SearchTarget.origin),
                  onClearOrigin: () => ref.read(navProvider.notifier).clearOrigin(),
                  onSearchTap: () => ref.read(navProvider.notifier).openSearch(),
                  onManualDrive: () {
                    final notifier = ref.read(locationProvider.notifier);
                    if (locationState.isManualDriving) {
                      notifier.stopManualDriving();
                    } else {
                      notifier.startManualDriving();
                    }
                    setState(() => _isFollowing = true);
                  },
                  onJustDrive: () {
                    ref.read(navProvider.notifier).startDriving();
                    setState(() => _isFollowing = true);
                  },
                ),
              ),
              // D-pad overlay when manual driving
              if (locationState.isManualDriving)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 280,
                  right: AppTheme.spacingMd,
                  child: const DrivePad(),
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
                child: Column(
                  children: [
                    _DarkButton(
                      icon: Icons.directions_car,
                      onTap: () => _showCarSelector(context),
                    ),
                    const SizedBox(height: 10),
                    _DarkButton(
                      icon: Icons.my_location,
                      onTap: _flyToUser,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: RoutePreviewPanel(
                  destination: navState.destination!,
                  route: navState.route,
                  currentProfile: navState.currentProfile,
                  isLoading: navState.isLoading,
                  onProfileChange: (p) => ref.read(navProvider.notifier).setRoutingProfile(p),
                  onStart: () =>
                      ref.read(navProvider.notifier).startNavigation(),
                  onSimulate: () {
                    ref.read(navProvider.notifier).startSimulatedNavigation();
                    setState(() => _isFollowing = true);
                  },
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
  final bool isManualDriving;
  final dynamic customOrigin;
  final VoidCallback onOriginTap;
  final VoidCallback onClearOrigin;
  final VoidCallback onSearchTap;
  final VoidCallback onManualDrive;
  final VoidCallback onJustDrive;

  const _WhereToPanel({
    required this.isManualDriving,
    this.customOrigin,
    required this.onOriginTap,
    required this.onClearOrigin,
    required this.onSearchTap,
    required this.onManualDrive,
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
                // Action buttons — 3 options
                Row(
                  children: [
                    // Just drive
                    _ActionBtn(
                      icon: Icons.drive_eta,
                      label: 'Drive',
                      onTap: onJustDrive,
                    ),
                    const SizedBox(width: 8),
                    // D-pad manual drive
                    _ActionBtn(
                      icon: isManualDriving ? Icons.stop_rounded : Icons.gamepad_rounded,
                      label: isManualDriving ? 'Stop' : 'D-Pad',
                      active: isManualDriving,
                      isStop: isManualDriving,
                      onTap: onManualDrive,
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

// === Action button for bottom panel ===

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isStop;
  final bool highlight;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.isStop = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    if (isStop) {
      bg = AppTheme.error;
      fg = Colors.white;
    } else if (highlight) {
      bg = AppTheme.accent;
      fg = AppTheme.bgDark;
    } else {
      bg = AppTheme.bgElevated;
      fg = AppTheme.textPrimary;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: (!isStop && !highlight)
                ? Border.all(color: AppTheme.bgSurface)
                : null,
            boxShadow: highlight && !isStop ? AppTheme.glowShadow : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
