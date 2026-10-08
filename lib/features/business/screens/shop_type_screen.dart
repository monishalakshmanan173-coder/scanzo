import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../data/models/shop_type.dart';
import '../../../shared/widgets/scanzo_logo.dart';
import '../../../app/routes.dart';

class ShopTypeScreen extends StatefulWidget {
  const ShopTypeScreen({super.key});

  @override
  State<ShopTypeScreen> createState() => _ShopTypeScreenState();
}

class _ShopTypeScreenState extends State<ShopTypeScreen> {
  String _selectedShopTypeId = 'retail';

  @override
  Widget build(BuildContext context) {
    final selectedShopType = ShopType.getById(_selectedShopTypeId);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScanzoLogo.icon(size: 28),
            const SizedBox(width: 10),
            const Text('Select Business Type'),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What kind of shop do you run?',
                    style: AppTypography.h2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We will customize your billing, units, and inventory categories accordingly.',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...ShopType.standardShopTypes.map((shopType) {
                    final isSelected = shopType.id == _selectedShopTypeId;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedShopTypeId = shopType.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? shopType.pastelColor : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? shopType.darkColor : AppColors.borderLight,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: shopType.darkColor.withOpacity(0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.surfaceWhite
                                    : shopType.pastelColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                shopType.icon,
                                color: shopType.darkColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shopType.title,
                                    style: AppTypography.h3.copyWith(
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    shopType.description,
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? shopType.darkColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? shopType.darkColor : AppColors.borderLight,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 4),

                  // Performance & Rating Benchmark Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: selectedShopType.pastelColor.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedShopType.darkColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_graph_rounded, color: selectedShopType.darkColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Performance & Category Rating',
                              style: AppTypography.h3.copyWith(
                                fontSize: 15,
                                color: selectedShopType.darkColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selectedShopType.darkColor.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${selectedShopType.rating} / 5.0',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceWhite,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Benchmark Margin', style: AppTypography.caption),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedShopType.benchmarkTurnover,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: selectedShopType.darkColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceWhite,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Industry Dynamics', style: AppTypography.caption),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedShopType.performanceBadge,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: selectedShopType.darkColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 18, color: selectedShopType.darkColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getTailoredCategoryDescription(_selectedShopTypeId),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ScanzoButton(
                text: 'Continue to Business Details',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.businessDetails,
                    arguments: {'shopTypeId': _selectedShopTypeId},
                  );
                },
                icon: Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTailoredCategoryDescription(String typeId) {
    switch (typeId.toLowerCase()) {
      case 'medical':
        return 'Preloads Chemist & Pharma categories, strips/tablets units, and batch/expiry tracking.';
      case 'electronics':
        return 'Preloads Mobiles, Gadgets, Cables, Audio & TV with brand & warranty tracking.';
      case 'clothing':
        return 'Preloads Men, Women, Kids apparel categories with Size & Fabric tags.';
      case 'grocery':
        return 'Preloads Kirana staples, FMCG, Dairy & Beverages with decimal weight support.';
      case 'bakery':
        return 'Preloads Cakes, Breads, Pastries & Drinks with daily fresh counter billing.';
      case 'retail':
        return 'Preloads General store items, Stationery, Gifts & FMCG with instant barcode scanning.';
      default:
        return 'Universal multi-product billing with flexible units, taxes, and inventory controls.';
    }
  }
}
