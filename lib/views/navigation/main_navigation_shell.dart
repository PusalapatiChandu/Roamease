import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../dashboard/home_dashboard_screen.dart';
import '../network/network_management_screen.dart';
import '../location/location_management_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final networkProvider = Provider.of<NetworkProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    // Attach notification provider to telemetry listeners
    final userId = authProvider.currentSubscriber?.uid ?? 'guest';
    final hasConsent = authProvider.currentSubscriber?.locationConsent ?? true;

    authProvider.attachNotificationProvider(notificationProvider);
    networkProvider.attachNotificationProvider(notificationProvider, userId);
    locationProvider.attachNotificationProvider(notificationProvider, userId, hasConsent);

    final screens = [
      HomeDashboardScreen(onNavigateTab: switchTab),
      const NetworkManagementScreen(),
      const LocationManagementScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: switchTab,
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.primaryBlue.withOpacity(0.18),
          elevation: 0,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryBlue),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: networkProvider.currentNetwork.isPoorConnection,
                backgroundColor: AppColors.signalPoor,
                child: const Icon(Icons.cell_tower_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: networkProvider.currentNetwork.isPoorConnection,
                backgroundColor: AppColors.signalPoor,
                child: const Icon(Icons.cell_tower_rounded, color: AppColors.primaryBlue),
              ),
              label: '5G Network',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: locationProvider.isTrackingActive,
                backgroundColor: AppColors.signalExcellent,
                child: const Icon(Icons.location_on_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: locationProvider.isTrackingActive,
                backgroundColor: AppColors.signalExcellent,
                child: const Icon(Icons.location_on_rounded, color: AppColors.primaryBlue),
              ),
              label: 'Location',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle_rounded, color: AppColors.primaryBlue),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
