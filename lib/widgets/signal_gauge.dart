import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';

class SignalGauge extends StatelessWidget {
  final int signalLevel; // 0 to 4
  final int dbm;
  final int asu;
  final String networkType;
  final String qualityLabel;

  const SignalGauge({
    super.key,
    required this.signalLevel,
    required this.dbm,
    required this.asu,
    required this.networkType,
    required this.qualityLabel,
  });

  Color _getSignalColor() {
    switch (qualityLabel) {
      case 'Excellent':
        return AppColors.signalExcellent;
      case 'Good':
        return AppColors.signalGood;
      case 'Fair':
        return AppColors.signalFair;
      case 'Poor':
      case 'Disconnected':
        return AppColors.signalPoor;
      default:
        return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getSignalColor();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SIGNAL METRICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  qualityLabel.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Signal Bars visualization
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (index) {
                  final barLevel = index + 1;
                  final isActive = signalLevel >= barLevel;
                  final barHeight = 12.0 + (index * 8.0);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 9,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isActive ? color : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              // Signal dBm readout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.formatDbm(dbm),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Power: ${Formatters.formatAsu(asu)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
              // Generation Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: networkType.contains('5G')
                      ? AppColors.card5GGradient
                      : const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  networkType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
