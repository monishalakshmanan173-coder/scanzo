import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_logo.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final AuthRepository _authRepo = AuthRepository();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleFinish() async {
    await _authRepo.completeOnboarding();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.shopType);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _handleFinish();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back, Brand Logo & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _previousPage,
                    )
                  else
                    const SizedBox(width: 48),
                  const ScanzoLogo.icon(size: 34),
                  TextButton(
                    onPressed: _handleFinish,
                    child: Text(
                      'Skip',
                      style: AppTypography.buttonText.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: const [
                  _OnboardingPageOne(),
                  _OnboardingPageTwo(),
                  _OnboardingPageThree(),
                ],
              ),
            ),

            // Bottom Navigation & Dots
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 26 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primaryPinkDark : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  ScanzoButton(
                    text: _currentPage == 2 ? 'Get Started' : 'Next',
                    onPressed: _nextPage,
                    icon: _currentPage == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// ONBOARDING 1: Cute Shop Entrance & Sparkles Animation
// ----------------------------------------------------
class _OnboardingPageOne extends StatefulWidget {
  const _OnboardingPageOne();

  @override
  State<_OnboardingPageOne> createState() => _OnboardingPageOneState();
}

class _OnboardingPageOneState extends State<_OnboardingPageOne> with SingleTickerProviderStateMixin {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen 1 Custom Animation: Shop Entrance & Floating Products
          SizedBox(
            height: 240,
            width: 260,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft pastel background halo
                    Container(
                      width: 200,
                      height: 200,
                      decoration: const BoxDecoration(
                        color: AppColors.softPeach,
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Cute Shop Building
                    Positioned(
                      bottom: 25,
                      child: Container(
                        width: 140,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x15D97757),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Roof Awning (Pink & Peach stripes)
                            Container(
                              height: 30,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryPink,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: Row(
                                children: List.generate(5, (i) {
                                  return Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: i.isEven ? AppColors.softPeach : AppColors.primaryPink,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const Spacer(),
                            // Shop Entrance Door
                            Container(
                              width: 36,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.softPeachDark.withOpacity(0.2),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppColors.softPeachDark,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Floating Product 1 (Floating grocery bag)
                    Positioned(
                      top: 40 + 10 * math.sin(t * 2 * math.pi),
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_rounded, color: AppColors.softPeachDark, size: 22),
                      ),
                    ),

                    // Floating Product 2 (Coffee / cup)
                    Positioned(
                      top: 30 + 12 * math.cos(t * 2 * math.pi),
                      right: 25,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_cafe_rounded, color: AppColors.primaryPinkDark, size: 22),
                      ),
                    ),

                    // Twinkling Sparkles
                    Positioned(
                      top: 15,
                      child: Opacity(
                        opacity: 0.4 + 0.6 * math.sin(t * math.pi),
                        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.lightYellowDark, size: 26),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Run Your Business Smarter',
            style: AppTypography.h1.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Manage your business, products and billing in one simple place.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// ONBOARDING 2: Moving Boxes & Shelves Inventory Animation
// --------------------------------------------------------------------
class _OnboardingPageTwo extends StatefulWidget {
  const _OnboardingPageTwo();

  @override
  State<_OnboardingPageTwo> createState() => _OnboardingPageTwoState();
}

class _OnboardingPageTwoState extends State<_OnboardingPageTwo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen 2 Custom Animation: Moving Boxes into Shelves & Stock Pill
          SizedBox(
            height: 240,
            width: 260,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: const BoxDecoration(
                        color: AppColors.mintGreen,
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Shelves Unit
                    Container(
                      width: 170,
                      height: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x123B8A61),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shelf 1
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBox(AppColors.pastelLavenderDark, 'Item A'),
                              Transform.translate(
                                offset: Offset((1.0 - t) * 20, 0),
                                child: _buildBox(AppColors.mintGreenDark, 'Item B'),
                              ),
                              _buildBox(AppColors.softPeachDark, 'Item C'),
                            ],
                          ),
                          Container(height: 2, color: AppColors.borderLight),
                          // Shelf 2
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBox(AppColors.babyBlueDark, 'Item D'),
                              _buildBox(AppColors.primaryPinkDark, 'Item E'),
                              Transform.translate(
                                offset: Offset(0, (1.0 - t) * -12),
                                child: _buildBox(AppColors.lightYellowDark, 'Item F'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Floating Stock Indicator Card
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'In Stock: ${(50 + (t * 10).toInt())}',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Keep Your Inventory Organized',
            style: AppTypography.h1.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Track products, stock levels and low-stock items easily.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBox(Color color, String label) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_rounded, size: 20, color: color),
      ),
    );
  }
}

// --------------------------------------------------------------------
// ONBOARDING 3: Sliding Receipt & Checkout Success Animation
// --------------------------------------------------------------------
class _OnboardingPageThree extends StatefulWidget {
  const _OnboardingPageThree();

  @override
  State<_OnboardingPageThree> createState() => _OnboardingPageThreeState();
}

class _OnboardingPageThreeState extends State<_OnboardingPageThree> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen 3 Custom Animation: Sliding Receipt with Total Counter & Success Checkmark
          SizedBox(
            height: 240,
            width: 260,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final slideOffset = (1.0 - math.min(t * 1.5, 1.0)) * 25.0;
                final showSuccess = t > 0.6;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: const BoxDecoration(
                        color: AppColors.pastelLavender,
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Sliding Receipt Card
                    Transform.translate(
                      offset: Offset(0, slideOffset),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x157E66B8),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_rounded, size: 28, color: AppColors.pastelLavenderDark),
                            const SizedBox(height: 4),
                            Text('SCANZO RECEIPT', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                            const Divider(height: 12),
                            _buildItemRow('Organic Flour x2', '₹110'),
                            const SizedBox(height: 4),
                            _buildItemRow('Tata Salt x1', '₹28'),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL:', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                                Text('₹138.00', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Success Checkmark Badge (Animates in)
                    if (showSuccess)
                      Positioned(
                        bottom: 25,
                        right: 35,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x3038A169),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Billing Made Simple',
            style: AppTypography.h1.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Create fast bills and manage daily sales with ease.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(price, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
