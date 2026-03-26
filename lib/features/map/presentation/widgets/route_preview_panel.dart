import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/place_model.dart';
import '../../domain/route_model.dart';

class RoutePreviewPanel extends StatelessWidget {
  final Place destination;
  final RouteInfo? route;
  final RoutingProfile currentProfile;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onSimulate;
  final VoidCallback onClose;
  final ValueChanged<RoutingProfile> onProfileChange;

  const RoutePreviewPanel({
    super.key,
    required this.destination,
    required this.route,
    required this.currentProfile,
    required this.isLoading,
    required this.onStart,
    required this.onSimulate,
    required this.onClose,
    required this.onProfileChange,
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
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Destination
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.location_on, color: AppTheme.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (destination.address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              destination.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Modes selection
                Row(
                  children: RoutingProfile.values.map((profile) {
                    final isSelected = profile == currentProfile;
                    final icon = profile == RoutingProfile.drivingTraffic
                        ? Icons.directions_car
                        : (profile == RoutingProfile.walking
                            ? Icons.directions_walk
                            : Icons.directions_bike);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onProfileChange(profile),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: isSelected ? AppTheme.accent : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Route info chips
                if (route != null) ...[
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.access_time,
                        label: route!.durationText,
                        highlight: true,
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.straighten,
                        label: route!.distanceText,
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.flag_outlined,
                        label: 'ETA ${route!.etaText}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Buttons
                Row(
                  children: [
                    // Cancel
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Simulate along route
                    Expanded(
                      child: GestureDetector(
                        onTap: route != null ? onSimulate : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: route != null ? AppTheme.bgElevated : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: route != null ? AppTheme.accent.withValues(alpha: 0.4) : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                color: route != null ? AppTheme.accent : AppTheme.textMuted, size: 20),
                              const SizedBox(width: 4),
                              Text('Test',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                  color: route != null ? AppTheme.accent : AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Start real navigation
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: route != null ? onStart : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: route != null ? AppTheme.accent : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: route != null ? AppTheme.glowShadow : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded,
                                color: route != null ? AppTheme.bgDark : AppTheme.textMuted, size: 20),
                              const SizedBox(width: 8),
                              Text(isLoading ? 'Finding...' : 'Start',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                  color: route != null ? AppTheme.bgDark : AppTheme.textMuted)),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.accent.withValues(alpha: 0.15)
            : AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppTheme.accent : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
