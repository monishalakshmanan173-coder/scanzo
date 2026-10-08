import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ShopType {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color pastelColor;
  final Color darkColor;

  const ShopType({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pastelColor,
    required this.darkColor,
  });

  static const List<ShopType> standardShopTypes = [
    ShopType(
      id: 'retail',
      title: 'Retail Shop',
      description: 'General store, stationery, gift shop & daily items',
      icon: Icons.storefront_rounded,
      pastelColor: AppColors.softPeach,
      darkColor: AppColors.softPeachDark,
    ),
    ShopType(
      id: 'grocery',
      title: 'Grocery / Supermarket',
      description: 'Kirana, FMCG, fresh produce & packaged foods',
      icon: Icons.local_grocery_store_rounded,
      pastelColor: AppColors.mintGreen,
      darkColor: AppColors.mintGreenDark,
    ),
    ShopType(
      id: 'bakery',
      title: 'Bakery & Cafe',
      description: 'Cakes, pastries, bread, beverages & confectioneries',
      icon: Icons.cake_rounded,
      pastelColor: AppColors.softPink,
      darkColor: AppColors.softPinkDark,
    ),
    ShopType(
      id: 'clothing',
      title: 'Clothing & Apparel',
      description: 'Garments, fashion, textiles, shoes & accessories',
      icon: Icons.checkroom_rounded,
      pastelColor: AppColors.pastelLavender,
      darkColor: AppColors.pastelLavenderDark,
    ),
    ShopType(
      id: 'electronics',
      title: 'Electronics Store',
      description: 'Mobiles, gadgets, appliances & repair services',
      icon: Icons.devices_rounded,
      pastelColor: AppColors.babyBlue,
      darkColor: AppColors.babyBlueDark,
    ),
    ShopType(
      id: 'other',
      title: 'Other Business',
      description: 'Wholesale, pharmacy, hardware or custom trade',
      icon: Icons.business_center_rounded,
      pastelColor: AppColors.lightYellow,
      darkColor: AppColors.lightYellowDark,
    ),
  ];
}
