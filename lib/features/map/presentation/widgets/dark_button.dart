import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DarkButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const DarkButton({super.key, required this.icon, required this.onTap});

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
