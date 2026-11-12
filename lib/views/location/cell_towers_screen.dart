import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/telecom_utils.dart';
import '../../providers/location_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/base_station_details_sheet.dart';
import '../../widgets/opencellid_config_dialog.dart';

class CellTowersScreen extends StatelessWidget {
  const CellTowersScreen({super.key});

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Strong':
        return AppColors.signalExcellent;
      case 'Moderate':
        return AppColors.signalFair;
      case 'Weak':
        return AppColors.signalPoor;
      default:
        return AppColors.textMutedDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkProvider = Provider.of<NetworkProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final towers = networkProvider.cellTowers;
    final mappedStations = networkProvider.mappedBaseStations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Base Stations & Cells'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Dataset Key & Search Radius',
            onPressed: () => showOpenCellIdConfigDialog(context),
          ),
          IconButton(
            icon: (networkProvider.isRefreshing || networkProvider.isScanningTowers)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Cells & Mapped Base Stations',
            onPressed: () async {
              await networkProvider.refreshNetworkDetails();
              final pos = locationProvider.currentPosition;
              if (pos != null) {
                await networkProvider.scanNearbyBaseStations(pos.latitude, pos.longitude, force: true);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authenticity & Dataset Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Authentic Telephony & Mapped Tower Datasets',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Platform.isAndroid
                              ? 'Measured dBm, RSRP, RSRQ & SINR come directly from Android TelephonyManager. Tower coordinates & coverage are resolved via OpenCelliD, beaconDB & OpenStreetMap.'
                              : 'Cellular modem scans are exclusively available on real Android hardware with Telephony permissions.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // SECTION 1: SERVING & NEIGHBOURING CELLS (ANDROID TELEPHONY)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DETECTED MODEM CELLS (${towers.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'Measured RF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.signalExcellent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (towers.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.cell_tower_rounded,
                        size: 42,
                        color: isDark ? AppColors.lightBlue : AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Serving & Neighbouring Cell Info Unavailable',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Android Telephony returned no cellular CellInfo entries. Verify Fine Location & Phone permissions are granted and an active SIM carrier is registered (not airplane mode or emulator).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => networkProvider.refreshNetworkDetails(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Rescan CellInfo'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...towers.map((tower) {
                final tierColor = _tierColor(tower.signalQualityTier);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tower.isRegistered
                          ? AppColors.signalExcellent.withOpacity(0.55)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: tower.isRegistered ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (tower.type.contains('5G')
                                            ? AppColors.cyan5G
                                            : AppColors.primaryBlue)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    tower.type.contains('5G')
                                        ? Icons.flash_on_rounded
                                        : Icons.cell_tower_rounded,
                                    size: 20,
                                    color: tower.type.contains('5G')
                                        ? AppColors.cyan5G
                                        : AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${tower.resolvedOperatorName} • ${tower.type}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Cell ID: ${tower.cellId}${tower.bandDescription != null ? " • ${tower.bandDescription}" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tower.isRegistered
                                      ? AppColors.signalExcellent.withOpacity(0.15)
                                      : (isDark ? Colors.white10 : Colors.black12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tower.cellRoleLabel,
                                  style: TextStyle(
                                    color: tower.isRegistered
                                        ? AppColors.signalExcellent
                                        : (isDark ? Colors.white70 : Colors.black54),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tierColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tower.signalQualityTier.toUpperCase(),
                                  style: TextStyle(
                                    color: tierColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetail('Signal', Formatters.formatDbm(tower.dbm), isDark),
                          _buildDetail('RSRP', tower.rsrp != null ? '${tower.rsrp} dBm' : 'Unavailable', isDark),
                          _buildDetail('RSRQ', tower.rsrq != null ? '${tower.rsrq} dB' : 'Unavailable', isDark),
                          _buildDetail('SINR', tower.sinr != null ? '${tower.sinr} dB' : 'Unavailable', isDark),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetail('TAC/LAC', tower.tac?.toString() ?? 'Unavailable', isDark),
                          _buildDetail('PCI', tower.pci?.toString() ?? 'Unavailable', isDark),
                          _buildDetail('TA', tower.timingAdvance?.toString() ?? 'Unavailable', isDark),
                          _buildDetail(
                            'Distance',
                            tower.hasMappedCoordinates
                                ? TelecomUtils.formatDistance(tower.distanceMeters)
                                : 'Unmapped',
                            isDark,
                          ),
                        ],
                      ),
                      if (tower.hasMappedCoordinates && tower.coordinateSource != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Resolved Coordinates (${tower.coordinateSource}): ${Formatters.formatCoordinates(tower.mappedLat!, tower.mappedLng!)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 22),

            // SECTION 2: MAPPED 4G & 5G BASE STATIONS (DATASETS & ESTIMATED COVERAGE)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MAPPED BASE STATIONS (${mappedStations.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showOpenCellIdConfigDialog(context),
                  icon: const Icon(Icons.key_rounded, size: 15),
                  label: Text(
                    networkProvider.openCellIdApiKey.isEmpty ? 'Add OpenCelliD Key' : 'Key Active',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Radius: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 6),
                ...[3000.0, 4000.0, 5000.0].map((r) {
                  final bool isSel = (networkProvider.towerSearchRadiusMeters - r).abs() < 250;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${(r / 1000).round()} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : AppColors.navyDark),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.cyan5G,
                      onSelected: (_) => networkProvider.setTowerSearchRadius(r),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),

            if (mappedStations.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.public_off_rounded,
                      size: 36,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No Mapped Base Stations Found Nearby',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      networkProvider.towerUnavailableNotes.isNotEmpty
                          ? networkProvider.towerUnavailableNotes.join('\n')
                          : 'No mapped tower entries were returned within search radius.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => showOpenCellIdConfigDialog(context),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Configure OpenCelliD Key / Expand Radius'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...mappedStations.map((station) {
                final Color genColor = station.isServingCell
                    ? AppColors.signalExcellent
                    : (station.is5g ? AppColors.cyan5G : AppColors.primaryBlue);

                return InkWell(
                  onTap: () => showBaseStationDetailsSheet(context, station),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: station.isServingCell
                            ? AppColors.signalExcellent.withOpacity(0.55)
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: genColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            station.is5g ? Icons.flash_on_rounded : Icons.cell_tower_rounded,
                            color: genColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      station.operatorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: genColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      station.generation,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: genColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${station.source} • Coverage: ${station.estimatedCoverageTier}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              station.formattedDistance,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: genColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              station.hasMeasuredSignal
                                  ? '${station.measuredSignalTier} (${station.measuredRsrp ?? station.measuredDbm} dBm)'
                                  : 'Tap details',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value, bool isDark) {
    final bool unavail = value == 'Unavailable' || value == 'Unmapped';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: unavail
                ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                : (isDark ? Colors.white : AppColors.navyDark),
          ),
        ),
      ],
    );
  }
}
