import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/network_provider.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkProvider = Provider.of<NetworkProvider>(context);
    final activeType = networkProvider.currentNetwork.networkType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('4G vs 5G Performance Matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Network Chip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.cyan5G, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Terminal Network: $activeType',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Compare your real-world mobile connection against 4G LTE and 5G NR architecture specifications.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'TELECOMMUNICATION METRIC BENCHMARKS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),

            // Comparison Rows
            _buildComparisonCard(
              context,
              metric: 'Peak Download Speed',
              icon: Icons.arrow_downward_rounded,
              fourGValue: '100 - 300 Mbps',
              fiveGValue: '1,000 - 10,000 Mbps',
              improvementRatio: '10x - 20x Faster',
              fourGPercent: 0.15,
              fiveGPercent: 0.95,
            ),
            const SizedBox(height: 12),

            _buildComparisonCard(
              context,
              metric: 'End-to-End Latency',
              icon: Icons.timer_outlined,
              fourGValue: '30 - 60 ms',
              fiveGValue: '1 - 10 ms (Ultra-Reliable Low-Latency)',
              improvementRatio: 'Up to 90% Reduced Delay',
              fourGPercent: 0.70,
              fiveGPercent: 0.10,
              isLowerBetter: true,
            ),
            const SizedBox(height: 12),

            _buildComparisonCard(
              context,
              metric: 'Typical Jitter (Packet Variance)',
              icon: Icons.graphic_eq_rounded,
              fourGValue: '10 - 25 ms',
              fiveGValue: '< 2 ms',
              improvementRatio: 'Smoother Roaming Streams',
              fourGPercent: 0.65,
              fiveGPercent: 0.08,
              isLowerBetter: true,
            ),
            const SizedBox(height: 12),

            _buildComparisonCard(
              context,
              metric: 'Maximum Device Density',
              icon: Icons.people_alt_outlined,
              fourGValue: '100,000 devices / km²',
              fiveGValue: '1,000,000 devices / km²',
              improvementRatio: '10x Higher Capacity',
              fourGPercent: 0.1,
              fiveGPercent: 1.0,
            ),
            const SizedBox(height: 12),

            _buildComparisonCard(
              context,
              metric: 'Radio Frequency Bands',
              icon: Icons.waves_rounded,
              fourGValue: '700 MHz – 2.6 GHz (Sub-3GHz)',
              fiveGValue: 'Sub-6 GHz & mmWave (24 – 40 GHz)',
              improvementRatio: 'Massive Bandwidth Aggregation',
              fourGPercent: 0.3,
              fiveGPercent: 0.9,
            ),
            const SizedBox(height: 12),

            _buildComparisonCard(
              context,
              metric: 'Roaming Handover Interruption',
              icon: Icons.sync_alt_rounded,
              fourGValue: '~80 - 120 ms',
              fiveGValue: '< 10 ms (Seamless 5G NR Handover)',
              improvementRatio: 'Zero Drop Voice/Data Roaming',
              fourGPercent: 0.8,
              fiveGPercent: 0.12,
              isLowerBetter: true,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(
    BuildContext context, {
    required String metric,
    required IconData icon,
    required String fourGValue,
    required String fiveGValue,
    required String improvementRatio,
    required double fourGPercent,
    required double fiveGPercent,
    bool isLowerBetter = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  Icon(icon, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    metric,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.signalExcellent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  improvementRatio,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.signalExcellent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4G Bar
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '4G LTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fourGPercent,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLowerBetter ? AppColors.signalPoor : AppColors.royalBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: Text(
                  fourGValue,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5G Bar
          Row(
            children: [
              const SizedBox(
                width: 44,
                child: Text(
                  '5G NR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan5G,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fiveGPercent,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLowerBetter ? AppColors.signalExcellent : AppColors.cyan5G,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: Text(
                  fiveGValue,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan5G,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
