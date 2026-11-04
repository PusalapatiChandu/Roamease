import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _deviceModelController;
  late String _selectedOperator;
  late String _selectedSimType;
  late bool _locationConsent;

  @override
  void initState() {
    super.initState();
    final subscriber = Provider.of<AuthProvider>(context, listen: false).currentSubscriber;

    _fullNameController = TextEditingController(text: subscriber?.fullName ?? '');
    _phoneController = TextEditingController(text: subscriber?.phone ?? '');
    _deviceModelController = TextEditingController(text: subscriber?.deviceModel ?? '');
    _selectedOperator = AppConstants.popularOperators.contains(subscriber?.operatorName)
        ? subscriber!.operatorName
        : AppConstants.popularOperators.first;
    _selectedSimType = subscriber?.simType ?? '5G';
    _locationConsent = subscriber?.locationConsent ?? true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _deviceModelController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final ok = await authProvider.updateProfile(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      operatorName: _selectedOperator,
      simType: _selectedSimType,
      deviceModel: _deviceModelController.text.trim(),
      locationConsent: _locationConsent,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscriber profile updated successfully in Cloud Firestore!'),
          backgroundColor: AppColors.signalExcellent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.signalPoor,
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
        title: const Text('Edit Subscriber Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modify Subscriber Credentials',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Update your telecom records stored in Firebase Cloud Firestore.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              CustomTextField(
                controller: _fullNameController,
                label: 'Full Name',
                prefixIcon: Icons.person_outline_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter full name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              CustomTextField(
                controller: _phoneController,
                label: 'Subscriber Mobile Number',
                prefixIcon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Network Operator Dropdown
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
                          Text('5G NR'),
                        ],
                      ),
                      selected: _selectedSimType == '5G',
                      selectedColor: AppColors.primaryBlue,
                      labelStyle: TextStyle(
                        color: _selectedSimType == '5G' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSimType = '5G');
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
                          Text('4G LTE'),
                        ],
                      ),
                      selected: _selectedSimType == '4G',
                      selectedColor: AppColors.primaryBlue,
                      labelStyle: TextStyle(
                        color: _selectedSimType == '4G' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSimType = '4G');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Device Model
              CustomTextField(
                controller: _deviceModelController,
                label: 'Device Hardware Model',
                prefixIcon: Icons.smartphone_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter device model';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Location Consent Switch
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
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
                        child: Text(
                          'Enable Permitted Travel GPS Tracking and Tower Triangulation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Save Button
              CustomButton(
                text: 'Save Changes to Profile',
                isLoading: authProvider.isLoading,
                icon: Icons.check_rounded,
                onPressed: _handleSave,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
