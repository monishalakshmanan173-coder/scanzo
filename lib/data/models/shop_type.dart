import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ShopType {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color pastelColor;
  final Color darkColor;
  final double rating;
  final int reviewsCount;
  final String performanceBadge;
  final String benchmarkTurnover;

  const ShopType({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pastelColor,
    required this.darkColor,
    this.rating = 4.8,
    this.reviewsCount = 240,
    this.performanceBadge = 'High Velocity',
    this.benchmarkTurnover = '15-25% Margin',
  });

  static const List<ShopType> standardShopTypes = [
    ShopType(
      id: 'retail',
      title: 'Retail Store',
      description: 'General store, stationery, gift shop, FMCG & daily items',
      icon: Icons.storefront_rounded,
      pastelColor: AppColors.softPeach,
      darkColor: AppColors.softPeachDark,
      rating: 4.8,
      reviewsCount: 310,
      performanceBadge: 'Fast Turnover',
      benchmarkTurnover: '12-18% FMCG Margin',
    ),
    ShopType(
      id: 'medical',
      title: 'Medical / Pharmacy',
      description: 'Chemist, prescription medicines, healthcare & wellness',
      icon: Icons.local_pharmacy_rounded,
      pastelColor: AppColors.mintGreen,
      darkColor: AppColors.mintGreenDark,
      rating: 4.9,
      reviewsCount: 420,
      performanceBadge: 'High Retention',
      benchmarkTurnover: '18-28% Healthcare Margin',
    ),
    ShopType(
      id: 'electronics',
      title: 'Electronics Store',
      description: 'Mobiles, gadgets, accessories, appliances & repairs',
      icon: Icons.devices_rounded,
      pastelColor: AppColors.babyBlue,
      darkColor: AppColors.babyBlueDark,
      rating: 4.8,
      reviewsCount: 290,
      performanceBadge: 'High Ticket',
      benchmarkTurnover: '20-35% Tech Margin',
    ),
    ShopType(
      id: 'clothing',
      title: 'Fashion Store',
      description: 'Garments, fashion, textiles, boutique & apparel',
      icon: Icons.checkroom_rounded,
      pastelColor: AppColors.pastelLavender,
      darkColor: AppColors.pastelLavenderDark,
      rating: 4.7,
      reviewsCount: 345,
      performanceBadge: 'High Margin',
      benchmarkTurnover: '35-50% Apparel Margin',
    ),
    ShopType(
      id: 'grocery',
      title: 'Grocery / Supermarket',
      description: 'Kirana, FMCG, fresh produce & packaged foods',
      icon: Icons.local_grocery_store_rounded,
      pastelColor: AppColors.mintGreen,
      darkColor: AppColors.mintGreenDark,
      rating: 4.7,
      reviewsCount: 380,
      performanceBadge: 'Daily Volume',
      benchmarkTurnover: '10-16% Volume Margin',
    ),
    ShopType(
      id: 'bakery',
      title: 'Bakery & Cafe',
      description: 'Cakes, pastries, bread, beverages & confectioneries',
      icon: Icons.cake_rounded,
      pastelColor: AppColors.softPink,
      darkColor: AppColors.softPinkDark,
      rating: 4.9,
      reviewsCount: 260,
      performanceBadge: 'Artisan Cafe',
      benchmarkTurnover: '40-55% Bakery Margin',
    ),
    ShopType(
      id: 'other',
      title: 'Other Business',
      description: 'Wholesale, hardware, customized trading or custom trade',
      icon: Icons.business_center_rounded,
      pastelColor: AppColors.lightYellow,
      darkColor: AppColors.lightYellowDark,
      rating: 4.6,
      reviewsCount: 180,
      performanceBadge: 'Flexible Operations',
      benchmarkTurnover: '15-30% Trade Margin',
    ),
  ];

  static ShopType getById(String id) {
    final cleanId = id.trim().toLowerCase();
    if (cleanId == 'fashion') return standardShopTypes.firstWhere((t) => t.id == 'clothing');
    if (cleanId == 'pharmacy') return standardShopTypes.firstWhere((t) => t.id == 'medical');
    return standardShopTypes.firstWhere(
      (t) => t.id == cleanId,
      orElse: () => standardShopTypes.last,
    );
  }
}
