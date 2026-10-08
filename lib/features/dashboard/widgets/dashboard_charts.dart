import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class DashboardSalesBarChart extends StatelessWidget {
  final List<DailySaleSummary> dailySales;

  const DashboardSalesBarChart({super.key, required this.dailySales});

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart_rounded, size: 36, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text('No sales data yet', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text('Complete bills to view daily trends', style: AppTypography.caption),
            ],
          ),
        ),
      );
    }

    final maxSale = dailySales.map((d) => d.totalSales).reduce(math.max);
    final displayMax = maxSale > 0 ? maxSale : 100.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Daily Sales', style: AppTypography.h3.copyWith(fontSize: 15)),
              Text('Peak: ${CurrencyFormatter.format(maxSale)}', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailySales.map((day) {
                final barRatio = (day.totalSales / displayMax).clamp(0.05, 1.0);
                final dayLabel = '${day.date.day}/${day.date.month}';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.totalSales > 0)
                          Text(
                            CurrencyFormatter.formatCompact(day.totalSales),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: barRatio,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primaryPinkDark,
                                      AppColors.softPeach,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(dayLabel, style: AppTypography.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardCategoryDonutChart extends StatelessWidget {
  final List<CategorySaleSummary> categorySales;

  const DashboardCategoryDonutChart({super.key, required this.categorySales});

  static const List<Color> _palette = [
    AppColors.softPeachDark,
    AppColors.pastelLavenderDark,
    AppColors.mintGreenDark,
    AppColors.babyBlueDark,
    AppColors.lightYellowDark,
    AppColors.primaryPinkDark,
  ];

  @override
  Widget build(BuildContext context) {
    if (categorySales.isEmpty) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pie_chart_outline_rounded, size: 36, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text('No category sales yet', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text('Sales by category will be visualized here', style: AppTypography.caption),
            ],
          ),
        ),
      );
    }

    final total = categorySales.map((c) => c.totalRevenue).reduce((a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales by Category', style: AppTypography.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              // Custom Donut Painter
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    items: categorySales,
                    total: total,
                    colors: _palette,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(math.min(categorySales.length, 4), (i) {
                    final cat = categorySales[i];
                    final color = _palette[i % _palette.length];
                    final pct = total > 0 ? (cat.totalRevenue / total * 100).toStringAsFixed(1) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(cat.category, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                          ),
                          Text('$pct%', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategorySaleSummary> items;
  final double total;
  final List<Color> colors;

  _DonutChartPainter({
    required this.items,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final sweepAngle = (item.totalRevenue / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
