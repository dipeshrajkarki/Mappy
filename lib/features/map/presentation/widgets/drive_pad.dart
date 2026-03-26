import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/location_provider.dart';

/// A virtual D-pad for manually driving the car around the map
class DrivePad extends ConsumerWidget {
  const DrivePad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationProvider);
    final speedKmh = loc.speedKmh.round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed display
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$speedKmh',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'km/h',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // D-pad
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bgCard.withValues(alpha: 0.7),
                  border: Border.all(
                    color: AppTheme.bgSurface,
                    width: 1.5,
                  ),
                ),
              ),

              // Up — accelerate
              Positioned(
                top: 8,
                child: _PadButton(
                  icon: Icons.arrow_drop_up_rounded,
                  size: 52,
                  color: AppTheme.accent,
                  onDown: () =>
                      ref.read(locationProvider.notifier).setThrottle(1.0),
                  onUp: () =>
                      ref.read(locationProvider.notifier).setThrottle(0),
                ),
              ),

              // Down — brake
              Positioned(
                bottom: 8,
                child: _PadButton(
                  icon: Icons.arrow_drop_down_rounded,
                  size: 52,
                  color: AppTheme.error,
                  onDown: () =>
                      ref.read(locationProvider.notifier).setThrottle(-1.0),
                  onUp: () =>
                      ref.read(locationProvider.notifier).setThrottle(0),
                ),
              ),

              // Left — steer left
              Positioned(
                left: 8,
                child: _PadButton(
                  icon: Icons.arrow_left_rounded,
                  size: 52,
                  onDown: () =>
                      ref.read(locationProvider.notifier).setSteering(-1.0),
                  onUp: () =>
                      ref.read(locationProvider.notifier).setSteering(0),
                ),
              ),

              // Right — steer right
              Positioned(
                right: 8,
                child: _PadButton(
                  icon: Icons.arrow_right_rounded,
                  size: 52,
                  onDown: () =>
                      ref.read(locationProvider.notifier).setSteering(1.0),
                  onUp: () =>
                      ref.read(locationProvider.notifier).setSteering(0),
                ),
              ),

              // Center dot
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bgElevated,
                  border: Border.all(color: AppTheme.bgSurface, width: 1),
                ),
                child: const Icon(
                  Icons.gamepad_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PadButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _PadButton({
    required this.icon,
    required this.size,
    this.color = AppTheme.textPrimary,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onDown();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? widget.color.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            color: _pressed
                ? widget.color
                : widget.color.withValues(alpha: 0.6),
            size: widget.size * 0.75,
          ),
        ),
      ),
    );
  }
}
