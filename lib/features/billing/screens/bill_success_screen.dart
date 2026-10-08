import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_logo.dart';
import '../../../data/models/sale.dart';
import '../../../app/routes.dart';

class BillSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> arguments;

  const BillSuccessScreen({super.key, required this.arguments});

  @override
  Widget build(BuildContext context) {
    final sale = arguments['sale'] as Sale;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ScanzoLogo.badge(size: 70),
                  const SizedBox(height: 16),

                  // Animated Success Icon Circle
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.mintGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x2038A169),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: AppColors.mintGreenDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Bill Generated Successfully!',
                    style: AppTypography.h2.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Invoice No: ${sale.invoiceNumber}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPinkDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Receipt Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Amount Paid', CurrencyFormatter.format(sale.grandTotal), isBold: true),
                        const Divider(height: 18),
                        _buildDetailRow('Payment Mode', sale.paymentMethod),
                        _buildDetailRow('Items Sold', '${sale.items.length} items'),
                        if (sale.customerName != null)
                          _buildDetailRow('Customer', sale.customerName!),
                        _buildDetailRow('Date & Time', DateFormatter.formatDateTime(sale.createdAt)),
                        if (sale.changeAmount > 0) ...[
                          const Divider(height: 18),
                          _buildDetailRow('Change Returned', CurrencyFormatter.format(sale.changeAmount), isBold: true),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  ScanzoButton(
                    text: 'View & Print Receipt',
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.receiptPreview,
                        arguments: {'sale': sale},
                      );
                    },
                    icon: Icons.receipt_long_rounded,
                    backgroundColor: AppColors.softPeach,
                    textColor: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 12),

                  ScanzoButton(
                    text: 'Create Another Bill',
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.posBilling);
                    },
                    icon: Icons.add_shopping_cart_rounded,
                  ),
                  const SizedBox(height: 12),

                  ScanzoButton(
                    text: 'Back to Dashboard',
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (r) => false);
                    },
                    isOutlined: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(
            value,
            style: isBold
                ? AppTypography.h3.copyWith(fontSize: 16)
                : AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
