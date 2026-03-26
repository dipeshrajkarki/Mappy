import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/location_provider.dart';
import '../../domain/route_model.dart';

// === Top bar: current turn instruction ===

class NavigationTopBar extends StatelessWidget {
  final RouteStep? currentStep;
  final RouteStep? nextStep;

  const NavigationTopBar({
    super.key,
    required this.currentStep,
    this.nextStep,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPadding),
          if (currentStep != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  // Maneuver icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      _maneuverIcon(currentStep!.maneuver),
                      color: AppTheme.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStep!.distanceText,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentStep!.instruction,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentStep!.streetName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentStep!.streetName,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
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
            ),

          // Next step preview
          if (nextStep != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: AppTheme.bgElevated,
              child: Row(
                children: [
                  const Text(
                    'Then',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _maneuverIcon(nextStep!.maneuver),
                    color: AppTheme.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nextStep!.instruction,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _maneuverIcon(String maneuver) {
    if (maneuver.contains('left')) return Icons.turn_left;
    if (maneuver.contains('right')) return Icons.turn_right;
    if (maneuver.contains('straight') || maneuver == 'depart') {
      return Icons.straight;
    }
    if (maneuver.contains('roundabout')) return Icons.roundabout_left;
    if (maneuver == 'arrive') return Icons.flag;
    if (maneuver.contains('merge')) return Icons.merge;
    if (maneuver.contains('fork')) return Icons.fork_right;
    if (maneuver.contains('uturn')) return Icons.u_turn_left;
    return Icons.straight;
  }
}

// === Bottom bar: ETA, distance, speed, stop ===

class NavigationBottomBar extends ConsumerWidget {
  final RouteInfo route;
  final VoidCallback onStop;

  const NavigationBottomBar({
    super.key,
    required this.route,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final loc = ref.watch(locationProvider);
    final speedKmh = loc.speedKmh.round();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
        child: Row(
          children: [
            // ETA
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.etaText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.durationText}  ·  ${route.distanceText}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Speed
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.bgSurface),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$speedKmh',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Finish trip button
            GestureDetector(
              onTap: onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.close, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'End',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
