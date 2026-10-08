import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

enum BadgeType { success, warning, error, info }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.success:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case BadgeType.warning:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case BadgeType.error:
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      case BadgeType.info:
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
