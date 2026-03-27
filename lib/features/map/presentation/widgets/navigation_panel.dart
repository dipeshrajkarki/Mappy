import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/location_provider.dart';
import '../../domain/route_model.dart';

// === Top bar: current turn instruction + lane guidance ===

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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

          // Lane guidance
          if (currentStep != null && currentStep!.hasLaneGuidance)
            _LaneGuidanceBar(lanes: currentStep!.lanes),

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

// === Lane guidance indicator ===

class _LaneGuidanceBar extends StatelessWidget {
  final List<LaneInfo> lanes;

  const _LaneGuidanceBar({required this.lanes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: AppTheme.bgElevated,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: lanes.map((lane) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _LaneArrow(lane: lane),
          );
        }).toList(),
      ),
    );
  }
}

class _LaneArrow extends StatelessWidget {
  final LaneInfo lane;

  const _LaneArrow({required this.lane});

  @override
  Widget build(BuildContext context) {
    final color = lane.valid
        ? AppTheme.accent
        : AppTheme.textMuted.withValues(alpha: 0.4);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: lane.valid
            ? AppTheme.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: lane.valid
              ? AppTheme.accent.withValues(alpha: 0.3)
              : AppTheme.bgSurface,
          width: 1,
        ),
      ),
      child: _buildArrowIcon(color),
    );
  }

  Widget _buildArrowIcon(Color color) {
    // Show the primary indication as an arrow icon
    final indication = lane.indications.isNotEmpty ? lane.indications.first : 'straight';

    final IconData icon;
    final double rotation;

    switch (indication) {
      case 'left':
        icon = Icons.arrow_upward_rounded;
        rotation = -0.785; // -45 degrees
      case 'slight left':
        icon = Icons.arrow_upward_rounded;
        rotation = -0.393; // -22.5 degrees
      case 'sharp left':
        icon = Icons.arrow_upward_rounded;
        rotation = -1.571; // -90 degrees
      case 'right':
        icon = Icons.arrow_upward_rounded;
        rotation = 0.785; // 45 degrees
      case 'slight right':
        icon = Icons.arrow_upward_rounded;
        rotation = 0.393; // 22.5 degrees
      case 'sharp right':
        icon = Icons.arrow_upward_rounded;
        rotation = 1.571; // 90 degrees
      case 'uturn':
        icon = Icons.u_turn_left;
        rotation = 0;
      case 'straight':
      default:
        icon = Icons.arrow_upward_rounded;
        rotation = 0;
    }

    if (rotation == 0 && icon != Icons.u_turn_left) {
      return Icon(icon, color: color, size: 18);
    }

    return Transform.rotate(
      angle: rotation,
      child: Icon(icon, color: color, size: 18),
    );
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
