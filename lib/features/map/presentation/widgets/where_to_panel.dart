import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/place_model.dart';

class WhereToPanel extends StatelessWidget {
  final Place? customOrigin;
  final VoidCallback onOriginTap;
  final VoidCallback onClearOrigin;
  final VoidCallback onSearchTap;

  const WhereToPanel({
    super.key,
    this.customOrigin,
    required this.onOriginTap,
    required this.onClearOrigin,
    required this.onSearchTap,
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
              width: 36,
              height: 4,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            customOrigin != null
                                ? customOrigin!.name
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
                            child: const Icon(
                              Icons.close,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                          )
                        else
                          const Icon(
                            Icons.my_location,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // TO field
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
