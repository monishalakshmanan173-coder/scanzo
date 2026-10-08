import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Official Scanzo Brand Logo Component
///
/// Renders the official Scanzo logo emblem featuring:
/// - Pastel pink circular emblem
/// - Cute smartphone/scan device concept
/// - Barcode & QR code scanning elements
/// - Whimsical sparkles & heart accents
/// - Official "Scanzo" branding & "Scan • Bill • Pay" tagline
class ScanzoLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final bool showBorder;
  final String? heroTag;
  final Color? backgroundColor;

  const ScanzoLogo({
    super.key,
    this.size = 96,
    this.showShadow = true,
    this.showBorder = false,
    this.heroTag,
    this.backgroundColor,
  });

  /// Small logo icon variant for AppBars, chips, and headers
  const ScanzoLogo.icon({
    super.key,
    this.size = 36,
    this.showShadow = false,
    this.showBorder = false,
    this.heroTag,
    this.backgroundColor,
  });

  /// Medium logo badge for cards and modals
  const ScanzoLogo.badge({
    super.key,
    this.size = 64,
    this.showShadow = true,
    this.showBorder = false,
    this.heroTag,
    this.backgroundColor,
  });

  /// Prominent full-size logo for splash, login, and onboarding screens
  const ScanzoLogo.large({
    super.key,
    this.size = 130,
    this.showShadow = true,
    this.showBorder = false,
    this.heroTag,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primaryPinkDark.withOpacity(0.18),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : null,
        border: showBorder
            ? Border.all(
                color: AppColors.primaryPinkLight,
                width: 2.0,
              )
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/scanzo_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Elegant vector fallback for unit tests or headless environments
            return _buildVectorFallback(size);
          },
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: logoWidget);
    }
    return logoWidget;
  }

  Widget _buildVectorFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF0F5),
            Color(0xFFF8BBD0),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: size * 0.52,
            color: AppColors.primaryPinkDark,
          ),
          Positioned(
            top: size * 0.16,
            right: size * 0.2,
            child: Icon(
              Icons.favorite_rounded,
              size: size * 0.18,
              color: AppColors.softRoseDark,
            ),
          ),
          Positioned(
            bottom: size * 0.12,
            child: Text(
              'Scanzo',
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryPinkDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
