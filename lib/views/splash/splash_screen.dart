import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/location_provider.dart';
import '../navigation/main_navigation_shell.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Initialize background state
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Warm up telemetry & location
    Provider.of<NetworkProvider>(context, listen: false).refreshNetworkDetails();
    Provider.of<LocationProvider>(context, listen: false).checkAndFetchLocation();

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDarkest,
      body: Stack(
        children: [
          // Background Gradient Glow
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Brand App Logo
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const AppLogo(
                    size: 96,
                    showShadow: true,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart Mobile Roaming & Location System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.lightBlue,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan5G),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Calibrating Telephony & GPS...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text(
              '5G Ready • Secure Firebase Backend',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMutedDark,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
