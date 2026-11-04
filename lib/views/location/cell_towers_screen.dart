import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/network_provider.dart';

class CellTowersScreen extends StatelessWidget {
  const CellTowersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkProvider = Provider.of<NetworkProvider>(context);
    final towers = networkProvider.cellTowers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Network Towers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: networkProvider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan Android CellInfo',
            onPressed: () => networkProvider.refreshNetworkDetails(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Information Banner
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
                  const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verified TelephonyManager CellInfo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Platform.isAndroid
                              ? 'Android Telephony APIs inspect local base transceiver stations (BTS/gNodeB) in real-time.'
                              : 'CellInfo queries are exclusively supported on real Android hardware with Telephony permissions.',
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

            Text(
              'DETECTED BASE STATIONS & TOWERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

            if (towers.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(28),
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
                        size: 48,
                        color: isDark ? AppColors.lightBlue : AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Reliable Tower Details Unavailable',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Per telecom specification, nearby mobile network tower data is only displayed when verified Android Telephony CellInfo is provided by the carrier and terminal.\n\nEnsure GPS Location & Phone permissions are granted and device is connected to an active cellular carrier (not airplane mode/emulator).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => networkProvider.refreshNetworkDetails(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Rescan Cell Towers'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...towers.map((tower) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tower.isRegistered
                          ? AppColors.primaryBlue.withOpacity(0.5)
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
                          Row(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tower.type,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Cell ID: ${tower.cellId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: tower.isRegistered
                                  ? AppColors.signalExcellent.withOpacity(0.15)
                                  : (isDark ? Colors.white10 : Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tower.isRegistered ? 'SERVING CELL' : 'NEIGHBOR',
                              style: TextStyle(
                                color: tower.isRegistered
                                    ? AppColors.signalExcellent
                                    : (isDark ? Colors.white70 : Colors.black54),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetail('Signal (dBm)', Formatters.formatDbm(tower.dbm)),
                          if (tower.tac != null) _buildDetail('TAC', tower.tac.toString()),
                          if (tower.pci != null) _buildDetail('PCI', tower.pci.toString()),
                          _buildDetail('Level', '${tower.level} / 4'),
                        ],
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
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
