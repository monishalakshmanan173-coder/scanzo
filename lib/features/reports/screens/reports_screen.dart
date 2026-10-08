import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../data/repositories/report_repository.dart';
import '../../dashboard/widgets/dashboard_charts.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _reportRepo = ReportRepository();

  String _selectedRange = 'This Month';
  ReportSummary? _summary;

  @override
  void initState() {
    super.initState();
    _applyRange('This Month');
  }

  void _applyRange(String range) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (range) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case 'Last 7 Days':
        start = DateTime(now.year, now.month, now.day - 7, 0, 0, 0);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case 'All Time':
      default:
        start = null;
        end = null;
        break;
    }

    setState(() {
      _selectedRange = range;
      _summary = _reportRepo.generateReport(startDate: start, endDate: end);
    });
  }

  void _exportCsv() {
    if (_summary == null || _summary!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction data to export.')),
      );
      return;
    }

    final csvContent = _reportRepo.exportReportToCsv(_summary!, _selectedRange);
    Clipboard.setData(ClipboardData(text: csvContent));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('CSV report has been formatted and copied to your clipboard. You can paste it into Excel or share it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(csvContent, subject: 'SCANZO Report - $_selectedRange');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: const Text('Share CSV Text', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Business Reports & Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Today', 'Last 7 Days', 'This Month', 'All Time'].map((r) {
                  final isSelected = _selectedRange == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r),
                      selected: isSelected,
                      selectedColor: AppColors.primaryPink,
                      onSelected: (sel) {
                        if (sel) _applyRange(r);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (_summary == null || _summary!.isEmpty) ...[
              const EmptyStateView(
                icon: Icons.analytics_outlined,
                title: 'No Sales Data for this Period',
                message: 'Complete bills in POS to see revenue, profit, tax summaries and product insights.',
              ),
            ] else ...[
              // Summary Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Revenue',
                      value: CurrencyFormatter.format(_summary!.totalSales),
                      subtitle: '${_summary!.totalBills} bills completed',
                      color: AppColors.primaryPinkDark,
                      bg: AppColors.primaryPinkLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Estimated Profit',
                      value: CurrencyFormatter.format(_summary!.totalEstimatedProfit),
                      subtitle: 'Gross revenue minus cost',
                      color: AppColors.mintGreenDark,
                      bg: AppColors.mintGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Taxes / GST Collected',
                      value: CurrencyFormatter.format(_summary!.totalGst),
                      subtitle: 'Output GST liability',
                      color: AppColors.pastelLavenderDark,
                      bg: AppColors.pastelLavender,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Discounts Given',
                      value: CurrencyFormatter.format(_summary!.totalDiscount),
                      subtitle: 'Store & product savings',
                      color: AppColors.softPeachDark,
                      bg: AppColors.softPeach,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Daily Sales Trends Chart
              Text('Daily Sales Trend', style: AppTypography.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              DashboardSalesBarChart(dailySales: _summary!.dailySales),
              const SizedBox(height: 20),

              // Category Sales Chart
              Text('Sales by Category', style: AppTypography.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              DashboardCategoryDonutChart(categorySales: _summary!.categorySales),
              const SizedBox(height: 20),

              // Payment Methods Breakdown
              Text('Payment Methods Used', style: AppTypography.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: _summary!.paymentMethodBreakdown.entries.map((e) {
                    final pct = _summary!.totalSales > 0 ? (e.value / _summary!.totalSales * 100).toStringAsFixed(1) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payment_rounded, size: 16, color: AppColors.babyBlueDark),
                              const SizedBox(width: 8),
                              Text(e.key, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('${CurrencyFormatter.format(e.value)} ($pct%)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Top Products Sold
              Text('Top Performing Products', style: AppTypography.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _summary!.topProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = _summary!.topProducts[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryPinkLight,
                        child: Text('#${idx + 1}', style: const TextStyle(color: AppColors.primaryPinkDark, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(item.productName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantitySold.toStringAsFixed(0)} units sold'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyFormatter.format(item.totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Profit: +${CurrencyFormatter.format(item.totalProfit)}',
                              style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.h3.copyWith(fontSize: 17, color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.caption),
        ],
      ),
    );
  }
}
