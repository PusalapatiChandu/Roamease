import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final subscriber = authProvider.currentSubscriber;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriber Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Subscriber Identity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.navyDark,
                      child: Text(
                        subscriber != null && subscriber.fullName.isNotEmpty
                            ? subscriber.fullName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan5G,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subscriber?.fullName ?? 'Registered Subscriber',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subscriber?.email ?? 'subscriber@roamease.io',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          subscriber?.simType ?? '5G Sub',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          subscriber?.operatorName ?? 'Operator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Telephony & Terminal Details
            Text(
              'TELECOMMUNICATION PROFILE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    title: 'Mobile Number',
                    value: subscriber?.phone ?? 'Not specified',
                    icon: Icons.phone_android_rounded,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildProfileTile(
                    title: 'Network Operator',
                    value: subscriber?.operatorName ?? 'Auto',
                    icon: Icons.network_cell_rounded,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildProfileTile(
                    title: 'SIM Network Class',
                    value: subscriber?.simType ?? '5G NR',
                    icon: Icons.flash_on_rounded,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildProfileTile(
                    title: 'Terminal Hardware Model',
                    value: subscriber?.deviceModel ?? 'Smartphone',
                    icon: Icons.smartphone_rounded,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildProfileTile(
                    title: 'GPS Location Consent',
                    value: subscriber?.locationConsent == true ? 'Consent Granted' : 'Consent Revoked',
                    icon: Icons.gps_fixed_rounded,
                    isDark: isDark,
                    valueColor: subscriber?.locationConsent == true ? AppColors.signalExcellent : AppColors.roamingWarning,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. User Settings & App Preferences
            Text(
              'APP PREFERENCES & ROAMING CONTROLS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Dark Theme Switch
                  SwitchListTile(
                    secondary: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    title: const Text('Dark Mode Palette', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Toggle professional navy dark theme', style: TextStyle(fontSize: 11)),
                    value: themeProvider.isDarkMode,
                    onChanged: (val) => themeProvider.toggleTheme(),
                  ),
                  _buildDivider(isDark),
                  // Roaming Mode Indicator/Toggle
                  SwitchListTile(
                    secondary: const Icon(Icons.public_rounded, color: AppColors.roamingWarning),
                    title: const Text('Manual Roaming Simulation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Flag subscriber account as travelling abroad', style: TextStyle(fontSize: 11)),
                    value: subscriber?.isRoaming ?? false,
                    onChanged: (val) {
                      authProvider.setRoamingStatus(val);
                    },
                  ),
                  _buildDivider(isDark),
                  // Push Notifications
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.cyan5G),
                    title: const Text('Connectivity & Weak Signal Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Notify when cellular signal drops below -110 dBm', style: TextStyle(fontSize: 11)),
                    value: StorageService.poorSignalAlerts,
                    onChanged: (val) async {
                      await StorageService.setPoorSignalAlerts(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Edit Profile Button
            CustomButton(
              text: 'Edit Subscriber Profile',
              icon: Icons.edit_note_rounded,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            // 5. Logout Button
            OutlinedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Secure Subscriber Logout'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.primaryBlue),
              ),
            ),

            const SizedBox(height: 12),

            // 6. Delete Account Button
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Subscriber Account?'),
                    content: const Text(
                      'This action will permanently delete your subscriber record, all location waypoints, and network history from Cloud Firestore. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final ok = await authProvider.deleteAccount();
                          if (context.mounted && ok) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: AppColors.signalPoor),
                        child: const Text('Delete Account'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.signalPoor),
              label: const Text('Delete Subscriber Account', style: TextStyle(color: AppColors.signalPoor)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: AppColors.signalPoor.withOpacity(0.5)),
              ),
            ),

            const SizedBox(height: 28),

            // App Brand Footer
            Center(
              child: Column(
                children: [
                  const AppLogo(size: 42, showShadow: false),
                  const SizedBox(height: 8),
                  Text(
                    'RoamEase v1.0.0',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Smart Mobile Roaming & Location System',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isDark ? Colors.white : AppColors.navyDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}
