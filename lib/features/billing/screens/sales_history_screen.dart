import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../app/routes.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _billingRepo = BillingRepository();
  final _searchController = TextEditingController();

  List<Sale> _allSales = [];
  List<Sale> _filteredSales = [];
  String _selectedMethod = 'All';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSales() {
    setState(() {
      _allSales = _billingRepo.getAllSales();
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSales = _allSales.where((s) {
        final matchesQuery = query.isEmpty ||
            s.invoiceNumber.toLowerCase().contains(query) ||
            (s.customerName != null && s.customerName!.toLowerCase().contains(query)) ||
            (s.customerMobile != null && s.customerMobile!.contains(query));

        final matchesMethod = _selectedMethod == 'All' || s.paymentMethod == _selectedMethod;
        return matchesQuery && matchesMethod;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Sales & Invoices History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: AppColors.backgroundCream,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search invoice number, customer name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Cash', 'UPI', 'Card', 'Other'].map((method) {
                      final isSelected = _selectedMethod == method;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(method),
                          selected: isSelected,
                          selectedColor: AppColors.primaryPink,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() {
                                _selectedMethod = method;
                                _applyFilter();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _filteredSales.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: _allSales.isEmpty ? 'No Invoices Yet' : 'No Matching Bills Found',
                    message: _allSales.isEmpty
                        ? 'Generate your first bill using the New Bill button on the dashboard.'
                        : 'Try searching with another keyword or clear the active filter.',
                    buttonText: _allSales.isEmpty ? 'Create First Bill' : null,
                    onButtonPressed: () => Navigator.pushNamed(context, AppRoutes.posBilling).then((_) => _loadSales()),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = _filteredSales[index];
                      return _buildSaleCard(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.receiptPreview,
          arguments: {'sale': sale},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPeach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_rounded, color: AppColors.softPeachDark, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sale.invoiceNumber, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(sale.grandTotal),
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sale.customerName ?? 'Walk-in'} • ${sale.paymentMethod}',
                        style: AppTypography.caption,
                      ),
                      Text(
                        DateFormatter.formatShortDate(sale.createdAt),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
