import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/services/session_service.dart';
import '../../../app/routes.dart';
import '../../../shared/widgets/scanzo_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final sessionService = SessionService();
    await sessionService.init();

    if (sessionService.isLoggedIn) {
      if (!sessionService.isOnboardingDone) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      } else if (!sessionService.isBusinessSetupDone) {
        Navigator.pushReplacementNamed(context, AppRoutes.shopType);
      } else {
        // Returning User with active session -> DIRECT TO DASHBOARD!
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } else {
      // First-time or logged out user -> Login Screen
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryPinkLight,
              AppColors.backgroundCream,
              AppColors.pastelLavender,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Official Scanzo Brand Logo
                      const ScanzoLogo.large(
                        size: 130,
                        heroTag: 'scanzo_logo',
                      ),
                      const SizedBox(height: 20),
                      // SCANZO Typography
                      Text(
                        AppConstants.appName,
                        style: AppTypography.h1.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.appTagline,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 48),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPinkDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
