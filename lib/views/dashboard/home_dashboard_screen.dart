import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/signal_gauge.dart';
import '../../widgets/status_badge.dart';
import '../network/speed_test_screen.dart';
import '../network/comparison_screen.dart';
import '../location/location_history_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const HomeDashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final networkProvider = Provider.of<NetworkProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);

    final subscriber = authProvider.currentSubscriber;
    final network = networkProvider.currentNetwork;
    final position = locationProvider.currentPosition;
    final address = locationProvider.currentAddress;
    final latestSpeed = networkProvider.latestSpeedTest;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 32, showShadow: false),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: notifProvider.unreadCount > 0,
              label: Text(notifProvider.unreadCount.toString()),
              backgroundColor: AppColors.signalPoor,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Alerts & Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: networkProvider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Telemetry',
            onPressed: () {
              networkProvider.refreshNetworkDetails();
              locationProvider.checkAndFetchLocation();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await networkProvider.refreshNetworkDetails();
          await locationProvider.checkAndFetchLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Card with Subscriber Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUBSCRIBER TERMINAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppColors.cyan5G.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subscriber != null ? 'Welcome, ${subscriber.fullName}' : 'Welcome, Subscriber',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${subscriber?.operatorName ?? network.operatorName} • ${subscriber?.simType ?? "5G"} Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: network.isConnected ? AppColors.signalExcellent : AppColors.signalPoor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                network.networkType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 16, color: AppColors.lightBlue),
                            const SizedBox(width: 6),
                            Text(
                              subscriber?.deviceModel ?? 'Android 5G Terminal',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                            ),
                          ],
                        ),
                        StatusBadge(
                          label: network.isRoaming ? 'ROAMING ACTIVE' : 'HOME CARRIER',
                          isRoaming: network.isRoaming,
                          color: network.isRoaming ? AppColors.roamingWarning : AppColors.signalExcellent,
                          fontSize: 10,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Active Connectivity Alert (if poor signal or roaming)
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
                      const Icon(Icons.warning_amber_rounded, color: AppColors.signalPoor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Poor Network Signal Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.signalPoor,
                              ),
                            ),
                            Text(
                              'Signal strength is ${network.signalStrengthDbm} dBm. Roaming coverage may be degraded.',
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
                const SizedBox(height: 14),
              ],

              // 3. Signal Strength Gauge
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

              // 4. Quick Access to All Three Main Modules
              Text(
                'QUICK MODULE ACCESS',
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
                    child: _buildModuleShortcut(
                      context,
                      title: 'Subscriber',
                      subtitle: 'Profile & SIM',
                      icon: Icons.person_rounded,
                      color: AppColors.royalBlue,
                      onTap: () => onNavigateTab?.call(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModuleShortcut(
                      context,
                      title: '5G Monitor',
                      subtitle: 'Bands & Speed',
                      icon: Icons.cell_tower_rounded,
                      color: AppColors.cyan5G,
                      onTap: () => onNavigateTab?.call(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModuleShortcut(
                      context,
                      title: 'Location',
                      subtitle: 'GPS & Towers',
                      icon: Icons.my_location_rounded,
                      color: AppColors.signalExcellent,
                      onTap: () => onNavigateTab?.call(2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 5. Real-time Location Widget
              Container(
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
                            const Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CURRENT SUBSCRIBER LOCATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (locationProvider.isTrackingActive)
                              const StatusBadge(label: 'TRACKING ON', color: AppColors.signalExcellent, fontSize: 10)
                            else
                              const StatusBadge(label: 'MANUAL', color: AppColors.textMutedDark, fontSize: 10),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!locationProvider.isLocationServiceEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.signalPoor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.signalPoor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_off_rounded, color: AppColors.signalPoor, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'GPS turned off on device. Tap to enable.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () => locationProvider.openLocationSettings(),
                              child: const Text('Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else if (!locationProvider.hasPermission) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: AppColors.primaryBlue, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Permission needed to detect location.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () => locationProvider.requestPermissionAndLocate(),
                              child: const Text('Grant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Text(
                      address?.city.isNotEmpty == true
                          ? '${address!.city}, ${address.area}'
                          : (position != null ? 'GPS Satellite Locked' : 'Locating subscriber...'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      position != null
                          ? '${Formatters.formatCoordinates(position.latitude, position.longitude)} • Accuracy: ±${position.accuracy.toStringAsFixed(1)}m'
                          : 'Tap to fetch live satellite coordinates',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Live Travel Speed Telemetry Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            locationProvider.currentTravelSpeedKmh > 1.0
                                ? Icons.speed_rounded
                                : Icons.place_rounded,
                            size: 16,
                            color: locationProvider.currentTravelSpeedKmh > 1.0
                                ? AppColors.signalExcellent
                                : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Travel Speed: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                          Text(
                            position != null
                                ? '${locationProvider.currentTravelSpeedKmh.toStringAsFixed(1)} km/h'
                                : '--',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: locationProvider.currentTravelSpeedKmh > 1.0
                                  ? AppColors.signalExcellent
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              locationProvider.speedStatusLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onNavigateTab?.call(2),
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text('Open Maps & Towers', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.save_alt_rounded, size: 18),
                          tooltip: 'Save Waypoint',
                          onPressed: () async {
                            final success = await locationProvider.saveCurrentLocation(subscriber?.uid ?? 'user');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Waypoint saved to history!' : 'Enable GPS to save location'),
                                  backgroundColor: success ? AppColors.signalExcellent : AppColors.signalPoor,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 6. Internet Speed & Bandwidth Overview
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Download Speed',
                      value: latestSpeed != null ? Formatters.formatSpeed(latestSpeed.downloadSpeedMbps) : '-- Mbps',
                      subtitle: latestSpeed != null ? 'Latency: ${latestSpeed.pingMs} ms' : 'Run speed test',
                      icon: Icons.arrow_downward_rounded,
                      iconColor: AppColors.signalExcellent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Upload Speed',
                      value: latestSpeed != null ? Formatters.formatSpeed(latestSpeed.uploadSpeedMbps) : '-- Mbps',
                      subtitle: latestSpeed != null ? 'Jitter: ${latestSpeed.jitterMs} ms' : 'Test network',
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.cyan5G,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 7. Network Performance Comparison & Analytics Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cyan5G.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: AppColors.cyan5G, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '5G vs 4G Performance Benchmark',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Compare latency, jitter, throughput and frequency bands side-by-side.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ComparisonScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.cyan5G,
                        foregroundColor: AppColors.navyDarkest,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 8. Recent Permitted Location History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT PERMITTED LOCATIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LocationHistoryScreen()),
                      );
                    },
                    child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (locationProvider.locationHistory.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No location waypoints recorded yet.\nTurn on Location Tracking in Module 3.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ...locationProvider.locationHistory.take(2).map((item) {
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
                      children: [
                        const Icon(Icons.history_rounded, size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.city.isNotEmpty ? '${item.city}, ${item.area}' : item.address,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${Formatters.formatCoordinates(item.latitude, item.longitude)} • ${Formatters.formatDateTime(item.timestamp)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
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

  Widget _buildModuleShortcut(
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
