import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../data/models/shop_type.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes.dart';

import '../../../shared/widgets/scanzo_animated_background.dart';
import '../../../shared/widgets/scanzo_logo.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _authRepo = AuthRepository();

  String _selectedBusinessType = 'Retail Shop';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final mobile = _mobileController.text.trim();
      final sentVerificationId = await _authRepo.sendOtp(
        mobile,
        isNewAccount: true,
      );
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'mobile': mobile,
          'verificationId': sentVerificationId,
          'ownerName': _ownerNameController.text.trim(),
          'businessName': _businessNameController.text.trim(),
          'email': _emailController.text.trim(),
          'businessType': _selectedBusinessType,
          'isNewAccount': true,
        },
      );
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^(Exception|AuthException|ValidationException):\s*'), '');
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Create New Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ScanzoAnimatedBackground(
        type: ScanzoBackgroundType.createAccount,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0E000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const ScanzoLogo.icon(size: 44),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Join SCANZO', style: AppTypography.h3),
                                    Text('Set up your store in 60 seconds', style: AppTypography.caption),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_errorMessage!.contains('already exists') || _errorMessage!.contains('log in')) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 38,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(context, AppRoutes.login);
                                        },
                                        icon: const Icon(Icons.login_rounded, size: 16),
                                        label: const Text('Log In to Existing Account',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryPinkDark,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          ScanzoTextField(
                            label: 'Owner Full Name *',
                            hint: 'e.g. Ramesh Kumar',
                            controller: _ownerNameController,
                            validator: (v) => Validators.validateRequired(v, 'Owner name'),
                          ),
                          const SizedBox(height: 14),

                          ScanzoTextField(
                            label: 'Business / Shop Name *',
                            hint: 'e.g. Ramesh Super Store',
                            controller: _businessNameController,
                            validator: (v) => Validators.validateRequired(v, 'Business name'),
                          ),
                          const SizedBox(height: 14),

                          ScanzoTextField(
                            label: 'Mobile Number *',
                            hint: '9876543210',
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validateMobile,
                            prefixIcon: Container(
                              padding: const EdgeInsets.only(left: 14, right: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+91',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: AppColors.borderLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          ScanzoTextField(
                            label: 'Email (Optional)',
                            hint: 'shop@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: 14),

                          // Business Type Selector
                          Text(
                            'Business Type',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedBusinessType,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceWhite,
                            ),
                            items: ShopType.standardShopTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.title,
                                child: Row(
                                  children: [
                                    Icon(type.icon, size: 18, color: type.darkColor),
                                    const SizedBox(width: 10),
                                    Text(type.title, style: AppTypography.bodyMedium),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedBusinessType = val);
                              }
                            },
                          ),
                          const SizedBox(height: 26),

                          ScanzoButton(
                            text: 'Create Account',
                            onPressed: _handleCreateAccount,
                            isLoading: _isLoading,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ', style: AppTypography.bodySmall),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Login here',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPinkDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
