import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/mapped_base_station_model.dart';

void showBaseStationDetailsSheet(
  BuildContext context,
  MappedBaseStationModel station,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final Color accent = station.isServingCell
      ? AppColors.signalExcellent
      : (station.is5g ? AppColors.cyan5G : AppColors.primaryBlue);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.45,
        maxChildSize: 0.88,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        station.is5g ? Icons.flash_on_rounded : Icons.cell_tower_rounded,
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.operatorName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${station.generation} • ${station.formattedDistance} away',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        station.isServingCell
                            ? 'SERVING'
                            : (station.isNeighbourCell ? 'NEIGHBOUR' : 'MAPPED'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Provenance Tag
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 15, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dataset Source: ${station.source}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section 1: Base Station Identity & Geometry
                Text(
                  'BASE STATION LOCATION & CELL IDENTITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.9,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Coordinates', Formatters.formatCoordinates(station.latitude, station.longitude), isDark),
                      _divider(isDark),
                      _infoRow('Distance to Subscriber', station.formattedDistance, isDark),
                      _divider(isDark),
                      _infoRow('Cell ID (CI / NCI)', station.cellId ?? 'Unavailable in dataset', isDark),
                      _divider(isDark),
                      _infoRow('TAC / LAC', station.tac?.toString() ?? 'Unavailable', isDark),
                      _divider(isDark),
                      _infoRow('Physical Cell ID (PCI)', station.pci?.toString() ?? 'Unavailable', isDark),
                      _divider(isDark),
                      _infoRow(
                        'MCC / MNC',
                        (station.mcc != null && station.mnc != null)
                            ? '${station.mcc}-${station.mnc}'
                            : 'Unavailable',
                        isDark,
                      ),
                      if (station.bandDescription != null) ...[
                        _divider(isDark),
                        _infoRow('Frequency Band', station.bandDescription!, isDark),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section 2: Actual Measured Signal (Android Telephony)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTUAL MEASURED SIGNAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.signalExcellent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ANDROID TELEPHONY API',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.signalExcellent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (station.hasMeasuredSignal)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.signalExcellent.withOpacity(0.45),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Signal Quality Classification', style: TextStyle(fontSize: 12)),
                            _qualityBadge(station.measuredSignalTier),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _metricBox('dBm', station.measuredDbm != null ? '${station.measuredDbm} dBm' : 'Unavailable', isDark),
                            _metricBox('RSRP', station.measuredRsrp != null ? '${station.measuredRsrp} dBm' : 'Unavailable', isDark),
                            _metricBox('RSRQ', station.measuredRsrq != null ? '${station.measuredRsrq} dB' : 'Unavailable', isDark),
                            _metricBox('SINR', station.measuredSinr != null ? '${station.measuredSinr} dB' : 'Unavailable', isDark),
                          ],
                        ),
                        if (station.timingAdvance != null) ...[
                          const SizedBox(height: 10),
                          _divider(isDark),
                          const SizedBox(height: 8),
                          _infoRow(
                            'LTE Timing Advance',
                            '${station.timingAdvance} TA (~${(station.timingAdvance! * 78)} m link timing)',
                            isDark,
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      'Actual measured RF telemetry (dBm, RSRP, RSRQ, SINR) is Unavailable for this specific tower because your device modem is not currently registered or reporting this physical mast/Cell ID.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                // Section 3: Estimated Network Coverage Dataset (Explicitly Labeled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ESTIMATED NETWORK COVERAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.roamingWarning.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ESTIMATED — NOT MEASURED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.roamingWarning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.roamingWarning.withOpacity(0.45),
                    ),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Coverage Model / Dataset', station.coverageDatasetLabel, isDark),
                      _divider(isDark),
                      _infoRow(
                        'Estimated Coverage Footprint',
                        '${(station.estimatedCoverageRadiusMeters / 1000).toStringAsFixed(2)} km radius (${station.estimatedCoverageRadiusMeters.round()} m)',
                        isDark,
                      ),
                      _divider(isDark),
                      _infoRow(
                        'Estimated Signal Zone at Distance',
                        station.estimatedCoverageTier,
                        isDark,
                      ),
                      _divider(isDark),
                      _infoRow(
                        'Model Path-Loss Reference',
                        '~${station.estimatedPathLossDbm} dBm (3GPP UMa Estimate)',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _infoRow(String label, String value, bool isDark) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: value.toLowerCase().contains('unavailable')
                  ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                  : (isDark ? Colors.white : AppColors.navyDark),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _divider(bool isDark) {
  return Divider(
    height: 1,
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
  );
}

Widget _metricBox(String label, String value, bool isDark) {
  final bool unavail = value == 'Unavailable';
  return Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: unavail
              ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
              : (isDark ? Colors.white : AppColors.navyDark),
        ),
      ),
    ],
  );
}

Widget _qualityBadge(String tier) {
  Color c;
  switch (tier) {
    case 'Strong':
      c = AppColors.signalExcellent;
      break;
    case 'Moderate':
      c = AppColors.signalFair;
      break;
    case 'Weak':
      c = AppColors.signalPoor;
      break;
    default:
      c = AppColors.textMutedDark;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      tier.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
    ),
  );
}

