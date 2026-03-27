import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String message;
  final bool showSettingsButton;
  final VoidCallback onOpenSettings;

  const ErrorBanner({
    super.key,
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
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showSettingsButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onOpenSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    color: AppTheme.bgDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
