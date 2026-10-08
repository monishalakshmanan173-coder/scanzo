import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum ScanzoBackgroundType {
  login,
  createAccount,
  otp,
  dashboard,
  products,
  inventory,
  billing,
  excelImport,
  general,
}

class ScanzoAnimatedBackground extends StatefulWidget {
  final ScanzoBackgroundType type;
  final Widget child;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final bool animate;

  const ScanzoAnimatedBackground({
    super.key,
    required this.type,
    required this.child,
    this.backgroundColor,
    this.gradientColors,
    this.animate = true,
  });

  @override
  State<ScanzoAnimatedBackground> createState() => _ScanzoAnimatedBackgroundState();
}

class _ScanzoAnimatedBackgroundState extends State<ScanzoAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Smooth, slow period (9 seconds) for calming, non-distracting floating drift
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ScanzoAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accessibility: Respect user reduced motion preference
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final gradientColors = widget.gradientColors ??
        const [
          AppColors.primaryPinkLight,
          AppColors.backgroundCream,
          AppColors.pastelLavender,
        ];

    return Stack(
      children: [
        // 1. Base Gradient Background
        Positioned.fill(
          child: Container(
            color: widget.backgroundColor ?? AppColors.backgroundCream,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
        ),

        // 2. Animated Floating Background Elements (Strictly Behind Foreground)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = reduceMotion ? 0.0 : _controller.value;
                  return _buildBackgroundElements(context, progress, reduceMotion);
                },
              ),
            ),
          ),
        ),

        // 3. Foreground Main Content
        Positioned.fill(child: widget.child),
      ],
    );
  }

  Widget _buildBackgroundElements(BuildContext context, double t, bool reduceMotion) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    switch (widget.type) {
      case ScanzoBackgroundType.login:
        return _buildLoginElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.createAccount:
        return _buildCreateAccountElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.otp:
        return _buildOtpElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.dashboard:
        return _buildDashboardElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.products:
        return _buildProductsElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.inventory:
        return _buildInventoryElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.billing:
        return _buildBillingElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.excelImport:
        return _buildExcelElements(w, h, t, reduceMotion);
      case ScanzoBackgroundType.general:
        return _buildGeneralElements(w, h, t, reduceMotion);
    }
  }

  // -------------------------------------------------------------
  // 1. LOGIN BACKGROUND
  // Small shopping bag, billing receipt, barcode, product box,
  // calculator, shop icon, coins, sparkles, soft circles, tiny pastel shapes
  // -------------------------------------------------------------
  Widget _buildLoginElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi);
    final wave3 = staticMode ? 0.0 : math.sin(t * 2 * math.pi + math.pi / 3);

    return Stack(
      children: [
        // Shopping Bag
        _animatedItem(
          icon: Icons.shopping_bag_outlined,
          color: AppColors.primaryPinkDark,
          size: 34,
          opacity: 0.16,
          left: w * 0.08 + wave1 * 12,
          top: h * 0.12 + wave2 * 14,
          rotation: wave1 * 0.1,
          scale: 1.0 + wave2 * 0.06,
        ),
        // Billing Receipt
        _animatedItem(
          icon: Icons.receipt_long_rounded,
          color: AppColors.softPeachDark,
          size: 38,
          opacity: 0.18,
          right: w * 0.10 + wave2 * 10,
          top: h * 0.16 + wave3 * 16,
          rotation: -wave2 * 0.12,
          scale: 1.0 + wave1 * 0.05,
        ),
        // Small Barcode
        _animatedItem(
          icon: Icons.barcode_reader,
          color: AppColors.babyBlueDark,
          size: 32,
          opacity: 0.15,
          left: w * 0.12 + wave3 * 8,
          bottom: h * 0.22 + wave1 * 14,
          rotation: wave3 * 0.08,
          scale: 1.0,
        ),
        // Product Box
        _animatedItem(
          icon: Icons.inventory_2_outlined,
          color: AppColors.mintGreenDark,
          size: 36,
          opacity: 0.16,
          right: w * 0.12 + wave1 * 14,
          bottom: h * 0.26 + wave2 * 12,
          rotation: wave1 * 0.08,
          scale: 1.0 + wave3 * 0.05,
        ),
        // Calculator
        _animatedItem(
          icon: Icons.calculate_outlined,
          color: AppColors.pastelPurpleDark,
          size: 30,
          opacity: 0.15,
          left: w * 0.06 + wave2 * 10,
          top: h * 0.48 + wave1 * 12,
          rotation: wave2 * 0.1,
          scale: 0.98,
        ),
        // Small Shop Icon
        _animatedItem(
          icon: Icons.store_rounded,
          color: AppColors.pastelLavenderDark,
          size: 40,
          opacity: 0.18,
          right: w * 0.07 + wave3 * 12,
          top: h * 0.52 + wave2 * 15,
          rotation: -wave1 * 0.08,
          scale: 1.02,
        ),
        // Coin / Currency
        _animatedItem(
          icon: Icons.monetization_on_outlined,
          color: AppColors.lightYellowDark,
          size: 26,
          opacity: 0.18,
          left: w * 0.22 + wave1 * 8,
          top: h * 0.07 + wave3 * 10,
          rotation: wave3 * 0.15,
          scale: 1.0,
        ),
        // Twinkling Sparkle 1
        _animatedItem(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.lightYellowDark,
          size: 24,
          opacity: 0.20 + (staticMode ? 0.0 : wave1 * 0.08),
          right: w * 0.25 + wave2 * 6,
          top: h * 0.09 + wave1 * 8,
          rotation: wave1 * 0.2,
          scale: 1.0 + wave2 * 0.1,
        ),
        // Twinkling Sparkle 2
        _animatedItem(
          icon: Icons.auto_awesome,
          color: AppColors.primaryPinkDark,
          size: 22,
          opacity: 0.18,
          right: w * 0.18 + wave3 * 8,
          bottom: h * 0.12 + wave2 * 10,
          rotation: wave2 * 0.15,
          scale: 1.0,
        ),
        // Soft Pastel Background Circles
        _softCircle(
          color: AppColors.primaryPinkLight,
          diameter: 120,
          opacity: 0.25,
          left: -40 + wave1 * 10,
          top: h * 0.25 + wave2 * 10,
        ),
        _softCircle(
          color: AppColors.pastelLavender,
          diameter: 140,
          opacity: 0.22,
          right: -50 + wave2 * 10,
          bottom: h * 0.35 + wave1 * 10,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 2. CREATE ACCOUNT BACKGROUND
  // Different arrangement: Product cards, shop icon, receipt,
  // small sparkles, soft pastel bubbles
  // -------------------------------------------------------------
  Widget _buildCreateAccountElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi + 1.0);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi + 0.5);

    return Stack(
      children: [
        // Product Card Badge
        _animatedItem(
          icon: Icons.style_outlined,
          color: AppColors.pastelLavenderDark,
          size: 36,
          opacity: 0.18,
          left: w * 0.07 + wave1 * 12,
          top: h * 0.18 + wave2 * 14,
          rotation: wave1 * 0.12,
          scale: 1.0,
        ),
        // Shop Icon
        _animatedItem(
          icon: Icons.storefront_rounded,
          color: AppColors.primaryPinkDark,
          size: 42,
          opacity: 0.20,
          right: w * 0.08 + wave2 * 10,
          top: h * 0.22 + wave1 * 15,
          rotation: -wave2 * 0.1,
          scale: 1.0 + wave1 * 0.05,
        ),
        // Receipt
        _animatedItem(
          icon: Icons.receipt_rounded,
          color: AppColors.softPeachDark,
          size: 34,
          opacity: 0.18,
          left: w * 0.10 + wave2 * 10,
          bottom: h * 0.20 + wave1 * 12,
          rotation: wave1 * 0.1,
          scale: 1.0,
        ),
        // Sparkles
        _animatedItem(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.lightYellowDark,
          size: 26,
          opacity: 0.22,
          right: w * 0.14 + wave1 * 8,
          bottom: h * 0.16 + wave2 * 10,
          rotation: wave2 * 0.2,
          scale: 1.05,
        ),
        // Soft Pastel Bubbles
        _softCircle(
          color: AppColors.softAqua,
          diameter: 100,
          opacity: 0.22,
          left: w * 0.15 + wave1 * 15,
          top: h * 0.08 + wave2 * 10,
        ),
        _softCircle(
          color: AppColors.pastelPurple,
          diameter: 130,
          opacity: 0.20,
          right: w * 0.05 + wave2 * 12,
          bottom: h * 0.30 + wave1 * 10,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 3. OTP BACKGROUND
  // Calmer, minimal: small floating dots, soft glowing circles,
  // tiny lock/security icon, subtle sparkles
  // -------------------------------------------------------------
  Widget _buildOtpElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 1.5 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 1.5 * math.pi);

    return Stack(
      children: [
        // Security Lock Icon
        _animatedItem(
          icon: Icons.shield_outlined,
          color: AppColors.primaryPinkDark,
          size: 32,
          opacity: 0.16,
          left: w * 0.12 + wave1 * 8,
          top: h * 0.15 + wave2 * 10,
          rotation: wave1 * 0.06,
          scale: 1.0,
        ),
        // Subtle Key / Check
        _animatedItem(
          icon: Icons.vpn_key_outlined,
          color: AppColors.pastelPurpleDark,
          size: 28,
          opacity: 0.14,
          right: w * 0.12 + wave2 * 8,
          top: h * 0.18 + wave1 * 10,
          rotation: -wave2 * 0.08,
          scale: 1.0,
        ),
        // Tiny Sparkle
        _animatedItem(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.lightYellowDark,
          size: 20,
          opacity: 0.16,
          right: w * 0.16 + wave1 * 6,
          bottom: h * 0.22 + wave2 * 8,
          rotation: wave1 * 0.1,
          scale: 1.0,
        ),
        // Floating Calming Pastel Dots
        _softCircle(
          color: AppColors.primaryPinkLight,
          diameter: 16,
          opacity: 0.22,
          left: w * 0.25 + wave1 * 6,
          top: h * 0.28 + wave2 * 6,
        ),
        _softCircle(
          color: AppColors.babyBlue,
          diameter: 14,
          opacity: 0.22,
          right: w * 0.28 + wave2 * 6,
          bottom: h * 0.35 + wave1 * 6,
        ),
        _softCircle(
          color: AppColors.pastelLavender,
          diameter: 90,
          opacity: 0.18,
          right: -20 + wave1 * 10,
          top: h * 0.05 + wave2 * 8,
        ),
        _softCircle(
          color: AppColors.mintGreen,
          diameter: 110,
          opacity: 0.16,
          left: -30 + wave2 * 8,
          bottom: h * 0.10 + wave1 * 8,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 4. DASHBOARD BACKGROUND
  // Very subtle, extremely slow: light pastel circles, small floating
  // business icons, soft decorative shapes, tiny sparkles.
  // Visual priority remains foreground cards!
  // -------------------------------------------------------------
  Widget _buildDashboardElements(double w, double h, double t, bool staticMode) {
    // Extra slow frequency for dashboard
    final wave1 = staticMode ? 0.0 : math.sin(t * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * math.pi);

    return Stack(
      children: [
        // Very light pastel circles
        _softCircle(
          color: AppColors.softPeach,
          diameter: 160,
          opacity: 0.14,
          left: -40 + wave1 * 8,
          top: h * 0.12 + wave2 * 6,
        ),
        _softCircle(
          color: AppColors.pastelLavender,
          diameter: 180,
          opacity: 0.12,
          right: -50 + wave2 * 8,
          top: h * 0.42 + wave1 * 8,
        ),
        _softCircle(
          color: AppColors.mintGreen,
          diameter: 140,
          opacity: 0.12,
          left: w * 0.10 + wave1 * 6,
          bottom: h * 0.05 + wave2 * 6,
        ),

        // Small floating business icons (Extremely low opacity so cards pop)
        _animatedItem(
          icon: Icons.store_mall_directory_outlined,
          color: AppColors.primaryPinkDark,
          size: 26,
          opacity: 0.09,
          right: w * 0.06 + wave1 * 6,
          top: h * 0.06 + wave2 * 6,
          rotation: wave1 * 0.05,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.receipt_long_outlined,
          color: AppColors.softPeachDark,
          size: 24,
          opacity: 0.09,
          left: w * 0.05 + wave2 * 6,
          top: h * 0.38 + wave1 * 6,
          rotation: -wave2 * 0.05,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.trending_up_rounded,
          color: AppColors.mintGreenDark,
          size: 26,
          opacity: 0.09,
          right: w * 0.08 + wave1 * 6,
          bottom: h * 0.20 + wave2 * 6,
          rotation: wave1 * 0.04,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.lightYellowDark,
          size: 18,
          opacity: 0.12,
          left: w * 0.15 + wave2 * 5,
          bottom: h * 0.15 + wave1 * 5,
          rotation: wave2 * 0.1,
          scale: 1.0,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 5. PRODUCTS SCREEN
  // Small product icons, boxes, tags, barcode shapes, low opacity
  // -------------------------------------------------------------
  Widget _buildProductsElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 1.8 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 1.8 * math.pi);

    return Stack(
      children: [
        _animatedItem(
          icon: Icons.sell_outlined,
          color: AppColors.primaryPinkDark,
          size: 32,
          opacity: 0.12,
          left: w * 0.06 + wave1 * 10,
          top: h * 0.15 + wave2 * 12,
          rotation: wave1 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.inventory_2_outlined,
          color: AppColors.mintGreenDark,
          size: 34,
          opacity: 0.12,
          right: w * 0.08 + wave2 * 10,
          top: h * 0.25 + wave1 * 12,
          rotation: -wave2 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.qr_code_2_rounded,
          color: AppColors.babyBlueDark,
          size: 36,
          opacity: 0.11,
          left: w * 0.08 + wave2 * 8,
          bottom: h * 0.22 + wave1 * 10,
          rotation: wave1 * 0.05,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.category_outlined,
          color: AppColors.pastelLavenderDark,
          size: 30,
          opacity: 0.12,
          right: w * 0.07 + wave1 * 8,
          bottom: h * 0.15 + wave2 * 10,
          rotation: wave2 * 0.06,
          scale: 1.0,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 6. INVENTORY SCREEN
  // Boxes, shelves, stock icons, up/down stock indicators
  // -------------------------------------------------------------
  Widget _buildInventoryElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi);

    return Stack(
      children: [
        _animatedItem(
          icon: Icons.all_inbox_rounded,
          color: AppColors.mintGreenDark,
          size: 34,
          opacity: 0.13,
          left: w * 0.07 + wave1 * 10,
          top: h * 0.18 + wave2 * 12,
          rotation: wave1 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.arrow_upward_rounded,
          color: AppColors.success,
          size: 26,
          opacity: 0.14,
          right: w * 0.12 + wave2 * 8,
          top: h * 0.20 + wave1 * 10,
          rotation: 0,
          scale: 1.0 + wave2 * 0.06,
        ),
        _animatedItem(
          icon: Icons.arrow_downward_rounded,
          color: AppColors.softRoseDark,
          size: 26,
          opacity: 0.14,
          left: w * 0.12 + wave2 * 8,
          bottom: h * 0.25 + wave1 * 10,
          rotation: 0,
          scale: 1.0 + wave1 * 0.06,
        ),
        _animatedItem(
          icon: Icons.table_rows_outlined,
          color: AppColors.babyBlueDark,
          size: 32,
          opacity: 0.12,
          right: w * 0.06 + wave1 * 8,
          bottom: h * 0.18 + wave2 * 10,
          rotation: wave2 * 0.06,
          scale: 1.0,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 7. BILLING SCREEN
  // Receipt, cart, product icons, payment icons
  // -------------------------------------------------------------
  Widget _buildBillingElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi);

    return Stack(
      children: [
        _animatedItem(
          icon: Icons.shopping_cart_outlined,
          color: AppColors.primaryPinkDark,
          size: 34,
          opacity: 0.13,
          left: w * 0.07 + wave1 * 10,
          top: h * 0.16 + wave2 * 12,
          rotation: wave1 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.receipt_outlined,
          color: AppColors.softPeachDark,
          size: 36,
          opacity: 0.14,
          right: w * 0.09 + wave2 * 10,
          top: h * 0.22 + wave1 * 12,
          rotation: -wave2 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.payments_outlined,
          color: AppColors.mintGreenDark,
          size: 30,
          opacity: 0.13,
          left: w * 0.10 + wave2 * 8,
          bottom: h * 0.20 + wave1 * 10,
          rotation: wave1 * 0.06,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.qr_code_rounded,
          color: AppColors.pastelPurpleDark,
          size: 32,
          opacity: 0.12,
          right: w * 0.08 + wave1 * 8,
          bottom: h * 0.14 + wave2 * 10,
          rotation: wave2 * 0.08,
          scale: 1.0,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 8. EXCEL IMPORT
  // Spreadsheet, product rows, file icon, upload arrow, product boxes
  // -------------------------------------------------------------
  Widget _buildExcelElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi);

    return Stack(
      children: [
        _animatedItem(
          icon: Icons.table_chart_outlined,
          color: AppColors.softAquaDark,
          size: 36,
          opacity: 0.15,
          left: w * 0.08 + wave1 * 10,
          top: h * 0.15 + wave2 * 12,
          rotation: wave1 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.upload_file_outlined,
          color: AppColors.primaryPinkDark,
          size: 34,
          opacity: 0.16,
          right: w * 0.10 + wave2 * 10,
          top: h * 0.20 + wave1 * 12,
          rotation: -wave2 * 0.08,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.cloud_upload_outlined,
          color: AppColors.babyBlueDark,
          size: 32,
          opacity: 0.14,
          left: w * 0.12 + wave2 * 8,
          bottom: h * 0.22 + wave1 * 10,
          rotation: wave1 * 0.06,
          scale: 1.0,
        ),
        _animatedItem(
          icon: Icons.inventory_2_outlined,
          color: AppColors.mintGreenDark,
          size: 32,
          opacity: 0.14,
          right: w * 0.08 + wave1 * 8,
          bottom: h * 0.16 + wave2 * 10,
          rotation: wave2 * 0.06,
          scale: 1.0,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 9. GENERAL BACKGROUND
  // -------------------------------------------------------------
  Widget _buildGeneralElements(double w, double h, double t, bool staticMode) {
    final wave1 = staticMode ? 0.0 : math.sin(t * 2 * math.pi);
    final wave2 = staticMode ? 0.0 : math.cos(t * 2 * math.pi);

    return Stack(
      children: [
        _softCircle(
          color: AppColors.primaryPinkLight,
          diameter: 120,
          opacity: 0.20,
          left: -30 + wave1 * 10,
          top: h * 0.15 + wave2 * 10,
        ),
        _softCircle(
          color: AppColors.pastelLavender,
          diameter: 140,
          opacity: 0.18,
          right: -40 + wave2 * 10,
          bottom: h * 0.25 + wave1 * 10,
        ),
      ],
    );
  }

  // Helper for single animated floating icon
  Widget _animatedItem({
    required IconData icon,
    required Color color,
    required double size,
    required double opacity,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double rotation,
    required double scale,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }

  // Helper for soft pastel background circles/shapes
  Widget _softCircle({
    required Color color,
    required double diameter,
    required double opacity,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
