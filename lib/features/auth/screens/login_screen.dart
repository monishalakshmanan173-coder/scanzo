import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes.dart';

import '../../../shared/widgets/scanzo_animated_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final mobile = _mobileController.text.trim();
      await _authRepo.sendOtp(mobile);
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'mobile': mobile,
          'isNewAccount': false,
        },
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: ScanzoAnimatedBackground(
        type: ScanzoBackgroundType.login,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x15F48FB1),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        size: 42,
                        color: AppColors.primaryPinkDark,
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      AppConstants.appName,
                      style: AppTypography.h1.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to Scanzo',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fast, cute & reliable billing for your store',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 32),

                    // Card Form
                    Container(
                      padding: const EdgeInsets.all(24),
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
                            Text(
                              'Login to Your Account',
                              style: AppTypography.h3.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 16),

                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        size: 18, color: AppColors.error),
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
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Mobile Input
                            ScanzoTextField(
                              label: 'Mobile Number',
                              hint: '9876543210',
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              validator: Validators.validateMobile,
                              prefixIcon: Container(
                                padding:
                                    const EdgeInsets.only(left: 14, right: 10),
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
                            const SizedBox(height: 20),

                            ScanzoButton(
                              text: 'Send OTP',
                              onPressed: _handleSendOtp,
                              isLoading: _isLoading,
                              icon: Icons.arrow_forward_rounded,
                            ),
                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Expanded(
                                    child: Container(
                                        height: 1,
                                        color: AppColors.borderLight)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child:
                                      Text('OR', style: AppTypography.caption),
                                ),
                                Expanded(
                                    child: Container(
                                        height: 1,
                                        color: AppColors.borderLight)),
                              ],
                            ),
                            const SizedBox(height: 18),

                            ScanzoButton(
                              text: 'Create New Account',
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, AppRoutes.createAccount);
                              },
                              isOutlined: true,
                              backgroundColor: AppColors.primaryPinkDark,
                              textColor: AppColors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'By continuing, you agree to SCANZO Terms of Service\nand Privacy Policy.',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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
