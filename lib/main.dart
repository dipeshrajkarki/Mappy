import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/map/presentation/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
  runApp(const ProviderScope(child: MappyApp()));
}

class MappyApp extends StatelessWidget {
  const MappyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mappy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MapScreen(),
    );
  }
}
