import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../application/location_provider.dart';
import '../application/navigation_provider.dart';
import '../domain/route_model.dart';
import 'widgets/dark_button.dart';
import 'widgets/error_banner.dart';
import 'widgets/search_sheet.dart';
import 'widgets/route_preview_panel.dart';
import 'widgets/navigation_panel.dart';
import 'widgets/where_to_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

/// Camera modes during navigation
enum CameraMode {
  /// Locked behind the car — camera follows heading smoothly, no swing
  lockedBehind,
  /// North is always up, camera follows position only
  northUp,
  /// Full route overview — flat top-down showing entire route
  overview,
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  bool _isFollowing = true;
  CameraMode _cameraMode = CameraMode.lockedBehind;
  PolylineAnnotationManager? _routeLineManager;
  PointAnnotationManager? _markerManager;
  PointAnnotationManager? _pointManager;
  PointAnnotation? _pointAnnotation;
  Uint8List? _arrowImageBytes;
  Uint8List? _customCarBytes;
  String _selectedVehicle = 'classic'; // default to 2D arrow (3D models need real GPU)
  DateTime _lastLocationUpdate = DateTime(0);
  static const _locationThrottleMs = 66; // ~15fps max for map updates

  final List<String> _availableVehicles = [
    'classic',
    'sedan',
    'suv',
    'taxi',
    'truck',
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
    } catch (e) {
      debugPrint('No custom car icon found: $e');
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

    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));

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

  Future<bool> _ensureModelLoaded(String modelName) async {
    if (modelName == 'classic' || _mapboxMap == null) return false;
    if (_loadedModels.contains(modelName)) return true;

    try {
      await _mapboxMap!.style.addStyleModel(
        modelName,
        'asset://assets/models/$modelName.glb',
      );
      _loadedModels.add(modelName);
      debugPrint('3D model "$modelName" loaded successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to load 3D model "$modelName": $e');
      return false;
    }
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
      await _mapboxMap!.style.addLayer(
        FillExtrusionLayer(
          id: 'buildings-3d',
          sourceId: 'composite',
          sourceLayer: 'building',
          minZoom: AppConstants.buildingMinZoom,
          fillExtrusionColor: const Color(AppConstants.buildingColor).toARGB32(),
          fillExtrusionHeightExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            14,
            0,
            14.5,
            ['get', 'height'],
          ],
          fillExtrusionBaseExpression: ['get', 'min_height'],
          fillExtrusionOpacity: AppConstants.buildingOpacity,
        ),
      );
    } catch (e) {
      debugPrint('Failed to enable 3D buildings: $e');
    }
  }

  bool _buildingsReduced = false;

  /// During navigation: make buildings short and translucent so they
  /// never block the view between the camera and the car.
  void _setBuildingsForNav(bool navigating) async {
    if (_mapboxMap == null) return;
    if (navigating == _buildingsReduced) return;
    _buildingsReduced = navigating;

    try {
      final layerExists = await _mapboxMap!.style.styleLayerExists('buildings-3d');
      if (!layerExists) return;

      if (navigating) {
        // Reduce buildings: cap height at ~8m (roughly 2 floors) and lower opacity
        await _mapboxMap!.style.setStyleLayerProperty(
          'buildings-3d',
          'fill-extrusion-height',
          ['min', ['get', 'height'], 8],
        );
        await _mapboxMap!.style.setStyleLayerProperty(
          'buildings-3d',
          'fill-extrusion-opacity',
          0.3,
        );
      } else {
        // Restore full buildings
        await _mapboxMap!.style.setStyleLayerProperty(
          'buildings-3d',
          'fill-extrusion-height',
          [
            'interpolate',
            ['linear'],
            ['zoom'],
            14,
            0,
            14.5,
            ['get', 'height'],
          ],
        );
        await _mapboxMap!.style.setStyleLayerProperty(
          'buildings-3d',
          'fill-extrusion-opacity',
          AppConstants.buildingOpacity,
        );
      }
    } catch (e) {
      debugPrint('Failed to update building style: $e');
    }
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
      } catch (e) {
        debugPrint('Failed to delete point annotation: $e');
      }
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

    // In locked-behind mode, arrow rotation must match the smoothed camera bearing
    // so the arrow always points "forward" on screen.
    // In north-up mode, use raw heading since the map doesn't rotate.
    final arrowRotation = _cameraMode == CameraMode.lockedBehind
        ? _smoothedBearing
        : loc.heading;

    try {
      if (_selectedVehicle == 'classic') {
        await _update2DArrow(loc, arrowRotation);
      } else {
        await _update3DModel(loc);
      }
    } catch (e) {
      debugPrint('Failed to update nav arrow: $e');
    }
    _updatingArrow = false;
  }

  Future<void> _update2DArrow(LocationState loc, double rotation) async {
    if (_pointManager == null) return;

    // Remove 3D layer if switching from 3D
    _remove3DLayer();

    final point = Point(coordinates: Position(loc.longitude!, loc.latitude!));
    final iconBytes = _customCarBytes ?? _arrowImageBytes;
    if (iconBytes == null) return;

    if (_pointAnnotation != null) {
      try {
        _pointAnnotation!.geometry = point;
        _pointAnnotation!.iconRotate = rotation;
        await _pointManager!.update(_pointAnnotation!);
      } catch (e) {
        debugPrint('Arrow update failed, recreating: $e');
        _pointAnnotation = null;
        _pointAnnotation = await _pointManager!.create(
          PointAnnotationOptions(
            geometry: point,
            image: iconBytes,
            iconSize: 0.35,
            iconRotate: rotation,
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
          iconRotate: rotation,
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
      } catch (e) {
        debugPrint('Failed to remove 2D arrow: $e');
      }
      _pointAnnotation = null;
    }

    final geojson =
        '{"type":"Feature","geometry":{"type":"Point","coordinates":[${loc.longitude},${loc.latitude}]}}';

    try {
      final sourceExists = await _mapboxMap!.style.styleSourceExists(
        _carSourceId,
      );
      if (sourceExists) {
        // Update position
        final src = await _mapboxMap!.style.getSource(_carSourceId);
        (src as GeoJsonSource).updateGeoJSON(geojson);
        // Update rotation
        if (await _mapboxMap!.style.styleLayerExists(_carLayerId)) {
          await _mapboxMap!.style.setStyleLayerProperty(
            _carLayerId,
            'model-rotation',
            [0.0, 0.0, loc.heading],
          );
        }
      } else {
        // Create source + layer
        await _mapboxMap!.style.addSource(
          GeoJsonSource(id: _carSourceId, data: geojson),
        );
        await _mapboxMap!.style.addLayer(
          ModelLayer(
            id: _carLayerId,
            sourceId: _carSourceId,
            modelId: _selectedVehicle,
            modelScale: [15.0, 15.0, 15.0],
            modelRotation: [0.0, 0.0, loc.heading],
            modelScaleMode: ModelScaleMode.MAP,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to update 3D model: $e');
    }
  }

  void _remove3DLayer() async {
    if (_mapboxMap == null) return;
    try {
      if (await _mapboxMap!.style.styleLayerExists(_carLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_carLayerId);
      }
      if (await _mapboxMap!.style.styleSourceExists(_carSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_carSourceId);
      }
    } catch (e) {
      debugPrint('Failed to remove 3D layer: $e');
    }
  }

  /// Fly to user — uses nav view if navigating, flat view otherwise
  void _flyToUser() {
    final loc = ref.read(locationProvider);
    if (!loc.hasLocation) return;

    setState(() {
      _isFollowing = true;
      // Exit overview mode when re-centering
      if (_cameraMode == CameraMode.overview) {
        _cameraMode = CameraMode.lockedBehind;
      }
    });
    final navState = ref.read(navProvider);
    final isNav = navState.mode == NavMode.navigating || navState.mode == NavMode.arriving;

    if (isNav) {
      _snapToNavView(loc);
    } else {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(loc.longitude!, loc.latitude!)),
          zoom: AppConstants.navigationZoom,
          bearing: 0,
          pitch: 0,
        ),
        MapAnimationOptions(duration: 800),
      );
    }
  }

  /// Instantly position camera in street-level nav view behind the car
  /// Uses setCamera (no animation) so the view is ready before simulation starts
  void _snapToNavView(LocationState loc) {
    if (!loc.hasLocation || _mapboxMap == null) return;

    final bearing = _cameraMode == CameraMode.northUp ? 0.0 : loc.heading;
    final reverseHeading = (loc.heading + 180) % 360;
    final offset = _offsetLatLng(
      loc.latitude!,
      loc.longitude!,
      reverseHeading,
      AppConstants.navOffsetMeters,
    );

    // Instant snap — no animation delay
    _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(offset.$2, offset.$1)),
        zoom: AppConstants.navZoom,
        bearing: bearing,
        pitch: AppConstants.navPitch,
      ),
    );
  }

  double _smoothedBearing = 0;

  void _updateCameraSmooth(LocationState loc, NavMode mode) {
    if (!loc.hasLocation || _mapboxMap == null) return;

    // In overview mode, don't move the camera — user is looking at the full route
    if (_cameraMode == CameraMode.overview) return;

    final isDriveView = mode == NavMode.navigating || mode == NavMode.arriving;
    final isStreetLevel =
        isDriveView || loc.isFakeGps || _selectedVehicle != 'classic';

    double bearing = 0;
    double pitch = 0;
    double zoom = AppConstants.navigationZoom;
    double centerLat = loc.latitude!;
    double centerLng = loc.longitude!;

    if (isStreetLevel) {
      pitch = AppConstants.navPitch;
      zoom = AppConstants.navZoom;

      if (_cameraMode == CameraMode.northUp) {
        bearing = 0;
      } else {
        // Locked behind: smooth the bearing to avoid jitter but keep it responsive
        var diff = loc.heading - _smoothedBearing;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smoothedBearing = (_smoothedBearing + diff * 0.4) % 360;
        if (_smoothedBearing < 0) _smoothedBearing += 360;
        bearing = _smoothedBearing;
      }

      // Offset camera center slightly BEHIND the car
      const offsetMeters = AppConstants.navOffsetMeters;
      final reverseHeading = (loc.heading + 180) % 360;
      final offset = _offsetLatLng(
        loc.latitude!,
        loc.longitude!,
        reverseHeading,
        offsetMeters,
      );
      centerLat = offset.$1;
      centerLng = offset.$2;
    }

    final duration = isStreetLevel ? AppConstants.cameraAnimDriveMs : AppConstants.cameraAnimIdleMs;

    _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
      ),
      MapAnimationOptions(duration: duration),
    );
  }

  /// Offset a lat/lng by [meters] in [bearing] degrees
  static (double, double) _offsetLatLng(
    double lat,
    double lng,
    double bearing,
    double meters,
  ) {
    const r = 6371000.0;
    final d = meters / r;
    final brng = bearing * pi / 180;
    final lat1 = lat * pi / 180;
    final lng1 = lng * pi / 180;
    final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng));
    final lng2 =
        lng1 +
        atan2(sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2));
    return (lat2 * 180 / pi, lng2 * 180 / pi);
  }

  void _cycleCameraMode() {
    final loc = ref.read(locationProvider);
    final navState = ref.read(navProvider);

    setState(() {
      switch (_cameraMode) {
        case CameraMode.lockedBehind:
          _cameraMode = CameraMode.northUp;
          break;
        case CameraMode.northUp:
          _cameraMode = CameraMode.overview;
          // Show route overview if we have a route
          if (navState.route != null) {
            _fitRouteBounds(navState.route!);
          }
          return; // don't call _updateCameraSmooth — overview handles its own camera
        case CameraMode.overview:
          _cameraMode = CameraMode.lockedBehind;
          _isFollowing = true;
          break;
      }
    });
    if (loc.hasLocation) {
      _snapToNavView(loc);
    }
  }

  void _drawRoute(RouteInfo route, {List<RouteInfo> alternatives = const []}) async {
    if (_routeLineManager == null) return;
    if (route.points.length < 2) return;

    await _routeLineManager!.deleteAll();
    await _markerManager?.deleteAll();

    // Draw alternative routes first (dimmed, behind main route)
    for (final alt in alternatives) {
      final altCoords = alt.points
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      if (altCoords.length >= 2) {
        await _routeLineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: altCoords),
            lineColor: AppTheme.textMuted.toARGB32(),
            lineWidth: 4.0,
            lineOpacity: 0.4,
          ),
        );
      }
    }

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
        return const Color(AppConstants.trafficSevere).toARGB32();
      case 'heavy':
        return const Color(AppConstants.trafficHeavy).toARGB32();
      case 'moderate':
        return const Color(AppConstants.trafficModerate).toARGB32();
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

    _mapboxMap
        ?.cameraForCoordinateBounds(
          CoordinateBounds(
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
            infiniteBounds: false,
          ),
          MbxEdgeInsets(top: 120, left: 60, bottom: 340, right: 60),
          null,
          null,
          null,
          null,
        )
        .then((camera) {
          // Force flat top-down view for route preview — no tilt, north-up
          final flatCamera = CameraOptions(
            center: camera.center,
            zoom: camera.zoom,
            bearing: 0,
            pitch: 0,
          );
          _mapboxMap?.flyTo(flatCamera, MapAnimationOptions(duration: 1000));
        });

    setState(() => _isFollowing = false);
  }

  void _clearRoute() async {
    await _routeLineManager?.deleteAll();
    await _markerManager?.deleteAll();
  }

  void _setVehicle(String vehicleType) async {
    if (vehicleType != 'classic') {
      final loaded = await _ensureModelLoaded(vehicleType);
      if (!loaded) {
        debugPrint('3D model "$vehicleType" not available, falling back to classic arrow');
        vehicleType = 'classic';
      }
    }
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
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                      title: Text(
                        isClassic ? 'Classic Arrow' : '3D $vehicle (.glb)',
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppTheme.accent)
                          : null,
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
    final navState = ref.watch(navProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final isNavMode = navState.mode == NavMode.navigating || navState.mode == NavMode.arriving;

    // Location updates — arrow + camera in sync (throttled to ~15fps)
    ref.listen<LocationState>(locationProvider, (prev, next) {
      final now = DateTime.now();
      if (now.difference(_lastLocationUpdate).inMilliseconds < _locationThrottleMs) return;
      _lastLocationUpdate = now;

      final shouldShowArrow =
          next.isFakeGps || isNavMode || _selectedVehicle != 'classic';

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
        _drawRoute(next.route!, alternatives: next.alternativeRoutes);
      }
      if (next.mode == NavMode.idle && prev?.mode != NavMode.idle) {
        _clearRoute();
        _deactivateArrow(); // remove arrow/3D model from map
        _flyToUser();
        _setBuildingsForNav(false); // restore full buildings
      }
      if (next.mode == NavMode.navigating && prev?.mode != NavMode.navigating) {
        setState(() {
          _isFollowing = true;
          _cameraMode = CameraMode.lockedBehind;
        });
        _setBuildingsForNav(true);
        // Instantly position camera BEFORE simulation starts moving the car
        final loc = ref.read(locationProvider);
        if (loc.hasLocation) {
          _smoothedBearing = loc.heading;
          _snapToNavView(loc);
        }
      }
    });

    final locationState = ref.watch(locationProvider);

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
                if (loc.isFakeGps || nav.mode == NavMode.navigating) {
                  return;
                }
                if (_isFollowing) setState(() => _isFollowing = false);
              },
            ),

            // === TOP GRADIENT ===
            if (!isNavMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
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
                    DarkButton(
                      icon: Icons.directions_car,
                      onTap: () => _showCarSelector(context),
                    ),
                    const SizedBox(height: 10),
                    DarkButton(icon: Icons.my_location, onTap: _flyToUser),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: WhereToPanel(
                  customOrigin: navState.origin,
                  onOriginTap: () => ref
                      .read(navProvider.notifier)
                      .openSearch(target: SearchTarget.origin),
                  onClearOrigin: () =>
                      ref.read(navProvider.notifier).clearOrigin(),
                  onSearchTap: () =>
                      ref.read(navProvider.notifier).openSearch(),
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
                child: Column(
                  children: [
                    DarkButton(
                      icon: Icons.directions_car,
                      onTap: () => _showCarSelector(context),
                    ),
                    const SizedBox(height: 10),
                    DarkButton(icon: Icons.my_location, onTap: _flyToUser),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RoutePreviewPanel(
                  destination: navState.destination!,
                  route: navState.route,
                  alternativeRoutes: navState.alternativeRoutes,
                  currentProfile: navState.currentProfile,
                  isLoading: navState.isLoading,
                  onProfileChange: (p) =>
                      ref.read(navProvider.notifier).setRoutingProfile(p),
                  onAlternativeSelected: (i) =>
                      ref.read(navProvider.notifier).selectAlternativeRoute(i),
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
                top: 0,
                left: 0,
                right: 0,
                child: NavigationTopBar(
                  currentStep: navState.currentStep,
                  nextStep: navState.nextStep,
                ),
              ),
              // GPS lost warning
              if (navState.gpsLost)
                Positioned(
                  top: topPadding + 140,
                  left: AppTheme.spacingMd,
                  right: AppTheme.spacingMd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gps_off, color: AppTheme.error, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'GPS signal lost',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: NavigationBottomBar(
                  route: navState.route!,
                  onStop: () => ref.read(navProvider.notifier).stopNavigation(),
                ),
              ),
            ],

            // === ARRIVING ===
            if (navState.mode == NavMode.arriving)
              Positioned(
                bottom: bottomPadding + 40,
                left: AppTheme.spacingLg,
                right: AppTheme.spacingLg,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: AppTheme.accent, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'You have arrived',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (navState.destination != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                navState.destination!.name,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ref.read(navProvider.notifier).stopNavigation(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: AppTheme.bgDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // === Right-side buttons (nav mode) ===
            if (isNavMode)
              Positioned(
                bottom: bottomPadding + 120,
                right: AppTheme.spacingMd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Camera mode: locked-behind → north-up → overview
                    DarkButton(
                      icon: _cameraMode == CameraMode.lockedBehind
                          ? Icons.navigation
                          : _cameraMode == CameraMode.northUp
                              ? Icons.explore
                              : Icons.map_outlined,
                      onTap: _cycleCameraMode,
                    ),
                    const SizedBox(height: 10),
                    // Re-center
                    DarkButton(
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
                child: ErrorBanner(
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

