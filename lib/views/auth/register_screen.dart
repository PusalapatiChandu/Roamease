import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../navigation/main_navigation_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deviceModelController = TextEditingController();

  String _selectedOperator = AppConstants.popularOperators.first;
  String _selectedSimType = '5G (NR Standalone / NSA)';
  bool _locationConsent = false;
  bool _isDetectingDevice = true;

  @override
  void initState() {
    super.initState();
    _detectDeviceModel();
  }

  Future<void> _detectDeviceModel() async {
    final deviceInfo = DeviceInfoPlugin();
    String modelName = 'Android 5G Smartphone';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        modelName = '${androidInfo.manufacturer.toUpperCase()} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        modelName = '${iosInfo.name} (${iosInfo.utsname.machine})';
      }
    } catch (_) {
      modelName = 'Universal Mobile Terminal';
    }

    if (mounted) {
      setState(() {
        _deviceModelController.text = modelName;
        _isDetectingDevice = false;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _deviceModelController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_locationConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant GPS location consent to enable travel location tracking.'),
          backgroundColor: AppColors.roamingWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.registerSubscriber(
      fullName: _fullNameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      operatorName: _selectedOperator,
      simType: _selectedSimType.contains('5G') ? '5G' : '4G',
      deviceModel: _deviceModelController.text.trim(),
      locationConsent: _locationConsent,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscriber registration successful! Welcome to RoamEase.'),
          backgroundColor: AppColors.signalExcellent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.signalPoor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriber Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Subscriber Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Register your SIM and terminal device for 5G roaming management',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Full Name
                CustomTextField(
                  controller: _fullNameController,
                  label: 'Full Legal Name',
                  hint: 'e.g. Alexander Wright',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter full name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mobile Number
                CustomTextField(
                  controller: _mobileController,
                  label: 'Mobile Subscriber Number',
                  hint: '+1 555 019 2834 or +91 98765 43210',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter mobile number';
                    if (val.trim().length < 8) return 'Enter valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Address
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'subscriber@domain.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter email address';
                    if (!val.contains('@') || !val.contains('.')) return 'Enter valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Operator Dropdown
                Text(
                  'Mobile Network Operator (Carrier)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.navyMedium,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedOperator,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.network_cell_rounded, color: AppColors.primaryBlue),
                  ),
                  items: AppConstants.popularOperators.map((op) {
                    return DropdownMenuItem(
                      value: op,
                      child: Text(op),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedOperator = val);
                  },
                ),
                const SizedBox(height: 16),

                // SIM Network Type (4G / 5G)
                Text(
                  'SIM Network Subscription Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.navyMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flash_on_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('5G NR Sub'),
                          ],
                        ),
                        selected: _selectedSimType.contains('5G'),
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _selectedSimType.contains('5G') ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedSimType = '5G (NR Standalone / NSA)');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.network_check_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('4G LTE Sub'),
                          ],
                        ),
                        selected: _selectedSimType.contains('4G'),
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _selectedSimType.contains('4G') ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedSimType = '4G (LTE / LTE-A)');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Device Model (Auto Detected & Editable)
                CustomTextField(
                  controller: _deviceModelController,
                  label: 'Subscriber Device Model (Auto-Detected)',
                  hint: 'Device hardware model',
                  prefixIcon: Icons.smartphone_rounded,
                  suffix: _isDetectingDevice
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          onPressed: _detectDeviceModel,
                        ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter device model';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter password';
                    if (val.length < 6) return 'Password must be >= 6 chars';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  validator: (val) {
                    if (val != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // User Consent for GPS Location Access Checkbox
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _locationConsent
                          ? AppColors.primaryBlue.withOpacity(0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _locationConsent,
                        activeColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          setState(() => _locationConsent = val ?? false);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _locationConsent = !_locationConsent);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Consent for GPS Location Access',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.navyDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'I agree to grant RoamEase permission to track my geographical coordinates while travelling to provide automated network roaming detection, cellular tower triangulation, and permitted location history. Tracking can be stopped anytime.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // Submit Button
                CustomButton(
                  text: 'Complete Subscriber Registration',
                  onPressed: _handleRegister,
                  isLoading: authProvider.isLoading,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
