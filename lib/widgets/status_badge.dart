import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool is5G;
  final bool isRoaming;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.is5G = false,
    this.isRoaming = false,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor = color ?? AppColors.primaryBlue;

    if (is5G) {
      badgeColor = AppColors.cyan5G;
    } else if (isRoaming) {
      badgeColor = AppColors.roamingWarning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: badgeColor),
            const SizedBox(width: 4),
          ] else if (is5G) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
