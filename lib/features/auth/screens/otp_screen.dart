import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes.dart';
import '../../../shared/widgets/scanzo_animated_background.dart';

class OtpScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const OtpScreen({super.key, required this.arguments});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authRepo = AuthRepository();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  int _resendTimer = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    setState(() => _errorMessage = null);
    final otp = _otpCode;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final mobile = widget.arguments['mobile'] ?? '';
      final ownerName = widget.arguments['ownerName'];
      final businessName = widget.arguments['businessName'];
      final email = widget.arguments['email'];
      final isNewAccount = widget.arguments['isNewAccount'] ?? false;

      await _authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: otp,
        ownerName: ownerName,
        businessName: businessName,
        email: email,
      );

      setState(() => _isSuccess = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      if (isNewAccount || !_authRepo.isOnboardingDone) {
        // Go to Onboarding (First-time user flow)
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.onboarding, (r) => false);
      } else if (!_authRepo.isBusinessSetupDone) {
        // Business setup
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shopType, (r) => false);
      } else {
        // Direct to Dashboard for returning user
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (r) => false);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Handle paste
      if (value.length > 1) {
        final digits = value.replaceAll(RegExp(r'\D'), '').split('');
        for (int i = 0; i < 6 && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        if (digits.isNotEmpty && digits.length <= 6) {
          _focusNodes[mathMin(digits.length, 5)].requestFocus();
        }
        if (_otpCode.length == 6) {
          _handleVerify();
        }
        return;
      }

      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6) {
          _handleVerify();
        }
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  int mathMin(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    final mobile = widget.arguments['mobile'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ScanzoAnimatedBackground(
        type: ScanzoBackgroundType.otp,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPinkLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 38,
                      color: AppColors.primaryPinkDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Enter Verification Code', style: AppTypography.h2),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sent 6-digit code to +91 $mobile',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Edit',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryPinkDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dev test OTP reminder hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Development test OTP: ${AppConstants.devTestOtp}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.lightYellowDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.caption.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 6 Digit OTP Input Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: AppTypography.h2.copyWith(fontSize: 22),
                          maxLength: 1,
                          autofocus: index == 0,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _controllers[index].text.isNotEmpty
                                    ? AppColors.primaryPinkDark
                                    : AppColors.borderLight,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryPinkDark,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (val) => _onOtpChanged(val, index),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  ScanzoButton(
                    text: _isSuccess ? 'Verified Successfully!' : 'Verify & Continue',
                    onPressed: _handleVerify,
                    isLoading: _isLoading,
                    backgroundColor: _isSuccess ? AppColors.success : AppColors.primaryPink,
                    icon: _isSuccess ? Icons.check_circle_rounded : Icons.check_rounded,
                  ),
                  const SizedBox(height: 20),

                  // Resend Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _resendTimer > 0
                            ? 'Resend OTP in $_resendTimer seconds'
                            : "Didn't receive the OTP? ",
                        style: AppTypography.bodySmall,
                      ),
                      if (_resendTimer == 0)
                        GestureDetector(
                          onTap: () {
                            _startResendTimer();
                            _authRepo.sendOtp(mobile);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP Resent successfully!')),
                            );
                          },
                          child: Text(
                            'Resend Code',
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
