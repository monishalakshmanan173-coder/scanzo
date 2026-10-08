import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'scanzo_button.dart';

/// Animated Empty State with cute floating illustration and gentle halo
class EmptyStateView extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color iconColor;
  final Color backgroundColor;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor = AppColors.primaryPinkDark,
    this.backgroundColor = AppColors.primaryPinkLight,
  });

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cute Floating Illustration with Sparkles
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = reduceMotion ? 0.0 : _controller.value;
                final floatOffset = math.sin(t * math.pi) * 8;

                return Transform.translate(
                  offset: Offset(0, -floatOffset),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Soft Halo
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: widget.backgroundColor.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Core Icon Bubble
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: widget.backgroundColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.backgroundColor.withOpacity(0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon, size: 38, color: widget.iconColor),
                      ),
                      // Little floating sparkle
                      Positioned(
                        top: -4 + (reduceMotion ? 0 : math.cos(t * math.pi) * 4),
                        right: -4,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: AppColors.lightYellowDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: AppTypography.h3.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.buttonText != null && widget.onButtonPressed != null) ...[
              const SizedBox(height: 22),
              ScanzoButton(
                text: widget.buttonText!,
                onPressed: widget.onButtonPressed,
                height: 44,
                icon: Icons.add_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly Error State with gentle shake animation
class ErrorStateView extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;

  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryText = 'Try Again',
  });

  @override
  State<ErrorStateView> createState() => _ErrorStateViewState();
}

class _ErrorStateViewState extends State<ErrorStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Gentle initial shake
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final t = _shakeController.value;
                // Gentle decaying shake
                final offset = reduceMotion
                    ? 0.0
                    : math.sin(t * 3 * math.pi) * (1.0 - t) * 8;

                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_dissatisfied_rounded,
                      size: 38,
                      color: AppColors.error,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: AppTypography.h3.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 20),
              ScanzoButton(
                text: widget.retryText,
                onPressed: () {
                  _shakeController.forward(from: 0.0);
                  widget.onRetry!();
                },
                height: 44,
                icon: Icons.refresh_rounded,
                backgroundColor: AppColors.primaryPinkDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Success State with animated checkmark and twinkling sparkles
class SuccessStateView extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onDone;
  final String doneText;

  const SuccessStateView({
    super.key,
    required this.title,
    required this.message,
    this.onDone,
    this.doneText = 'Continue',
  });

  @override
  State<SuccessStateView> createState() => _SuccessStateViewState();
}

class _SuccessStateViewState extends State<SuccessStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.mintGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x253B8A61),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 44,
                      color: AppColors.mintGreenDark,
                    ),
                  ),
                  const Positioned(
                    top: -6,
                    right: -6,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: AppColors.lightYellowDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.title,
              style: AppTypography.h3.copyWith(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onDone != null) ...[
              const SizedBox(height: 22),
              ScanzoButton(
                text: widget.doneText,
                onPressed: widget.onDone,
                height: 44,
                icon: Icons.check_circle_outline_rounded,
                backgroundColor: AppColors.success,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
