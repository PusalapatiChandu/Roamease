import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/telecom_utils.dart';
import '../../providers/location_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/base_station_details_sheet.dart';
import '../../widgets/opencellid_config_dialog.dart';
import '../../widgets/signal_gauge.dart';
import 'speed_test_screen.dart';
import 'comparison_screen.dart';
import 'network_analytics_screen.dart';
import '../location/cell_towers_screen.dart';

class NetworkManagementScreen extends StatelessWidget {
  const NetworkManagementScreen({super.key});

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

    final network = networkProvider.currentNetwork;
    final latestSpeed = networkProvider.latestSpeedTest;
    final servingCell = networkProvider.servingCell;
    final neighbours = networkProvider.neighbouringCells;
    final servingOrNearestMapped =
        networkProvider.servingMappedStation ?? networkProvider.nearestMappedStation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('5G Network Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Base Station Dataset Settings',
            onPressed: () => showOpenCellIdConfigDialog(context),
          ),
          IconButton(
            icon: networkProvider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Network & Base Stations',
            onPressed: () async {
              await networkProvider.refreshNetworkDetails();
              final pos = locationProvider.currentPosition;
              if (pos != null) {
                await networkProvider.scanNearbyBaseStations(
                  pos.latitude,
                  pos.longitude,
                  force: true,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await networkProvider.refreshNetworkDetails();
          final pos = locationProvider.currentPosition;
          if (pos != null) {
            await networkProvider.scanNearbyBaseStations(
              pos.latitude,
              pos.longitude,
              force: true,
            );
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Network Status Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: network.is5gActive
                      ? AppColors.card5GGradient
                      : const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                              Icon(
                                network.is5gActive ? Icons.flash_on_rounded : Icons.cell_tower_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  network.operatorName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            network.networkType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTelecomStat('Connection', network.isConnected ? 'Connected' : 'Offline', Colors.white),
                        _buildTelecomStat('Roaming', network.isRoaming ? 'Active' : 'Home', Colors.white),
                        _buildTelecomStat('SIM State', network.simState, Colors.white),
                        _buildTelecomStat('Signal Tier', network.signalQualityTier, Colors.white),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Poor Connection Warning Alert (if applicable)
              if (network.isPoorConnection) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.signalPoor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.signalPoor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                          color: AppColors.signalPoor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weak Signal Level Detected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.signalPoor),
                            ),
                            Text(
                              'Measured signal is ${Formatters.formatDbm(network.signalStrengthDbm)}. Data rates may experience high packet loss.',
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
                const SizedBox(height: 16),
              ],

              // 3. Android Telephony Signal Strength Gauge
              SignalGauge(
                signalLevel: network.signalLevel,
                dbm: network.signalStrengthDbm,
                asu: network.signalAsu,
                networkType: network.networkType,
                qualityLabel: network.qualityLabel,
                signalQualityTier: network.signalQualityTier,
                rsrp: network.rsrp,
                rsrq: network.rsrq,
                sinr: network.sinr,
              ),

              const SizedBox(height: 16),

              // 4. Serving Cell & Neighbouring Base Station RF Quality Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sensors_rounded, color: AppColors.cyan5G, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'SERVING CELL & RF QUALITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: _tierColor(network.signalQualityTier).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            network.signalQualityTier.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _tierColor(network.signalQualityTier),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // RSRP / RSRQ / SINR Measured Strip
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRfTile(
                            'RSRP',
                            network.rsrp != null ? '${network.rsrp} dBm' : 'Unavailable',
                            isDark,
                          ),
                          _buildRfTile(
                            'RSRQ',
                            network.rsrq != null ? '${network.rsrq} dB' : 'Unavailable',
                            isDark,
                          ),
                          _buildRfTile(
                            'SINR',
                            network.sinr != null ? '${network.sinr} dB' : 'Unavailable',
                            isDark,
                          ),
                          _buildRfTile(
                            'TA',
                            network.timingAdvance != null ? '${network.timingAdvance}' : 'Unavailable',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Serving Cell ID / TAC / PCI / Band
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildCompactChip(
                          'Serving Cell ID: ${servingCell?.cellId ?? network.servingCellId ?? "Unavailable"}',
                          isDark,
                        ),
                        _buildCompactChip(
                          'PCI: ${servingCell?.pci ?? network.servingPci ?? "Unavailable"}',
                          isDark,
                        ),
                        _buildCompactChip(
                          'TAC: ${servingCell?.tac ?? network.servingTac ?? "Unavailable"}',
                          isDark,
                        ),
                        if (network.mcc != null && network.mnc != null)
                          _buildCompactChip('MCC-MNC: ${network.mcc}-${network.mnc}', isDark),
                        if (network.bandDescription != null)
                          _buildCompactChip(network.bandDescription!, isDark),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    const SizedBox(height: 10),

                    // Neighbouring Cells & Mapped Base Station Distance Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cells: ${servingCell != null ? "1 Serving" : "0 Serving"}, ${neighbours.length} Neighbours',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                servingOrNearestMapped != null
                                    ? '${servingOrNearestMapped.isServingCell ? "Serving Tower" : "Nearest Mapped Tower"}: ${TelecomUtils.formatDistance(servingOrNearestMapped.distanceMeters)} (${servingOrNearestMapped.generation})'
                                    : (networkProvider.isScanningTowers
                                        ? 'Scanning mapped base station datasets...'
                                        : 'Mapped tower distance unavailable for current cell'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (servingOrNearestMapped != null)
                          TextButton(
                            onPressed: () => showBaseStationDetailsSheet(context, servingOrNearestMapped),
                            child: const Text('Inspect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CellTowersScreen()),
                          );
                        },
                        icon: const Icon(Icons.cell_tower_rounded, size: 17),
                        label: Text(
                          'Inspect Detected Cells (${networkProvider.cellTowers.length}) & Mapped Towers (${networkProvider.mappedBaseStations.length})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Clearly Labelled Speed-Test Tool
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed_rounded, color: AppColors.primaryBlue, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'REAL-TIME SPEED TEST',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          latestSpeed != null
                              ? Formatters.formatTimeOnly(latestSpeed.timestamp)
                              : 'No Tests Yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              Text(
                                latestSpeed != null
                                    ? Formatters.formatSpeed(latestSpeed.downloadSpeedMbps)
                                    : '-- Mbps',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.signalExcellent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              Text(
                                latestSpeed != null
                                    ? Formatters.formatSpeed(latestSpeed.uploadSpeedMbps)
                                    : '-- Mbps',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cyan5G,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latency',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              Text(
                                latestSpeed != null ? '${latestSpeed.pingMs} ms' : '-- ms',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.navyDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Open Interactive Speedometer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 6. Navigation Shortcuts: 4G vs 5G Comparison & Network Analytics
              Text(
                'NETWORK TOOLS & BENCHMARKS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      context,
                      title: '4G vs 5G Compare',
                      subtitle: 'Bandwidth & Latency',
                      icon: Icons.compare_arrows_rounded,
                      color: AppColors.accentIndigo,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ComparisonScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      context,
                      title: 'Network Analytics',
                      subtitle: 'Graphs & History',
                      icon: Icons.show_chart_rounded,
                      color: AppColors.cyan5G,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NetworkAnalyticsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildActionTile(
                context,
                title: 'Base Stations & Serving Cells',
                subtitle: 'Android CellInfo + OpenCelliD / beaconDB / OSM towers',
                icon: Icons.cell_tower_rounded,
                color: AppColors.royalBlue,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CellTowersScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // 7. Recent Speed Test History Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONNECTION HISTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (networkProvider.speedHistory.isNotEmpty)
                    Text(
                      '${networkProvider.speedHistory.length} logs',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (networkProvider.speedHistory.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No network connection logs recorded yet.\nRun a speed test to log performance history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ...networkProvider.speedHistory.take(4).map((test) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (test.networkType.contains('5G')
                                        ? AppColors.cyan5G
                                        : AppColors.primaryBlue)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                test.networkType.contains('5G')
                                    ? Icons.flash_on_rounded
                                    : Icons.network_cell_rounded,
                                size: 18,
                                color: test.networkType.contains('5G')
                                    ? AppColors.cyan5G
                                    : AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '↓ ${Formatters.formatSpeed(test.downloadSpeedMbps)} • ↑ ${Formatters.formatSpeed(test.uploadSpeedMbps)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${test.networkType} • ${test.pingMs} ms • ${Formatters.formatTimeOnly(test.timestamp)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          Formatters.formatDateOnly(test.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRfTile(String label, String value, bool isDark) {
    final bool unavailable = value == 'Unavailable';
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
            color: unavailable
                ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                : (isDark ? Colors.white : AppColors.navyDark),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  Widget _buildTelecomStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMutedDark),
          ],
        ),
      ),
    );
  }
}
