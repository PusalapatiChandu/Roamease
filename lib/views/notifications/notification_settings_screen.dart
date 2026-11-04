import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final prefs = notifProvider.preferences;
    final userId = authProvider.currentSubscriber?.uid ?? 'guest';

    final usedGb = prefs.currentDataUsedMb / 1024.0;
    final limitGb = prefs.dataLimitGb;
    final usagePercent = limitGb > 0 ? (usedGb / limitGb).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Master Toggle Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: prefs.allNotificationsEnabled
                    ? AppColors.heroGradient
                    : const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: prefs.allNotificationsEnabled
                        ? AppColors.primaryBlue.withOpacity(0.3)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      prefs.allNotificationsEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RoamEase Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prefs.allNotificationsEnabled
                              ? 'Real-time alerts for 5G, roaming & security are active'
                              : 'All in-app and heads-up notifications are paused',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: prefs.allNotificationsEnabled,
                    activeColor: AppColors.cyan5G,
                    onChanged: (val) {
                      notifProvider.updatePreferences(
                        prefs.copyWith(allNotificationsEnabled: val),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Category Alert Toggles
            Text(
              'ALERT CATEGORIES & EVENT TRIGGERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

            _buildCategorySection(
              context,
              children: [
                _buildToggleTile(
                  context,
                  title: 'Network & 5G Transitions',
                  subtitle: 'Alerts when switching between 4G LTE and 5G NR bands',
                  icon: Icons.cell_tower_rounded,
                  color: AppColors.cyan5G,
                  value: prefs.networkChanges && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(networkChanges: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Cellular Connection State',
                  subtitle: 'Immediate notices when connection is lost or restored',
                  icon: Icons.signal_cellular_alt_rounded,
                  color: AppColors.signalExcellent,
                  value: prefs.connectionState && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(connectionState: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Weak Signal Warnings (< -110 dBm)',
                  subtitle: 'Notifies when cellular reception degrades during roaming',
                  icon: Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                  color: AppColors.signalPoor,
                  value: prefs.poorSignal && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(poorSignal: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Significant Location Changes',
                  subtitle: 'Notifies when crossing municipal or city boundaries with consent',
                  icon: Icons.my_location_rounded,
                  color: AppColors.accentIndigo,
                  value: prefs.significantLocation && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(significantLocation: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Roaming Network Status',
                  subtitle: 'Alerts when operating on foreign or domestic partner carriers',
                  icon: Icons.public_rounded,
                  color: AppColors.roamingWarning,
                  value: prefs.roamingAlerts && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(roamingAlerts: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Data Usage Threshold Warnings',
                  subtitle: 'Warning alerts at 80% and 100% of configured monthly quota',
                  icon: Icons.data_usage_rounded,
                  color: AppColors.royalBlue,
                  value: prefs.dataUsageAlerts && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(dataUsageAlerts: val),
                  ),
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  context,
                  title: 'Account & SIM Security',
                  subtitle: 'Authentication notices, login alerts, and profile updates',
                  icon: Icons.security_rounded,
                  color: AppColors.primaryBlue,
                  value: prefs.securityAlerts && prefs.allNotificationsEnabled,
                  enabled: prefs.allNotificationsEnabled,
                  onChanged: (val) => notifProvider.updatePreferences(
                    prefs.copyWith(securityAlerts: val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Monthly Data Quota & Warning Config
            Text(
              'MONTHLY DATA USAGE CONFIGURATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

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
                          const Icon(Icons.pie_chart_rounded, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Data Allowance Quota',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${usedGb.toStringAsFixed(2)} GB / ${limitGb.toStringAsFixed(0)} GB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: usagePercent,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        usagePercent >= 1.0
                            ? AppColors.signalPoor
                            : (usagePercent >= 0.8 ? AppColors.roamingWarning : AppColors.cyan5G),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Select Monthly Data Limit:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quota Options
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2.0, 5.0, 10.0, 20.0, 50.0].map((gb) {
                      final isSelected = (limitGb - gb).abs() < 0.1;
                      return ChoiceChip(
                        label: Text('$gb GB'),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            notifProvider.setDataLimitGb(gb, userId);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Billing Cycle Counter',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          notifProvider.resetDataUsage(userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Data usage counter reset to 0 MB.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset Counter', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Android System Permission & FCM Push Diagnostics
            Text(
              'PUSH NOTIFICATION ENGINE & PERMISSIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

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
                    children: [
                      const Icon(Icons.phonelink_ring_rounded, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Firebase Cloud Messaging (FCM)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppColors.navyDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RoamEase uses FCM push tokens combined with high-priority Android notification channels for background and foreground delivery.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                          label: const Text('Android App Settings', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () {
                          final token = NotificationService.fcmToken;
                          if (token != null && token.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: token));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('FCM Device Token copied to clipboard!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Awaiting Firebase Cloud Messaging token generation...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy Device FCM Token',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          Switch.adaptive(
            value: value,
            activeColor: AppColors.cyan5G,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}

