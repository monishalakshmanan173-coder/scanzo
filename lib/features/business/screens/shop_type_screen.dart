import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../data/models/shop_type.dart';
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
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Select Business Type'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ShopType.standardShopTypes.length,
                itemBuilder: (context, index) {
                  final shopType = ShopType.standardShopTypes[index];
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
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
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
}
