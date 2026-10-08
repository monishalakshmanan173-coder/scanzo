import '../database/database_helper.dart';

class DailySaleSummary {
  final DateTime date;
  final double totalSales;
  final int totalBills;

  DailySaleSummary({
    required this.date,
    required this.totalSales,
    required this.totalBills,
  });
}

class ProductSaleSummary {
  final String productId;
  final String productName;
  final double quantitySold;
  final double totalRevenue;
  final double totalProfit;

  ProductSaleSummary({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalProfit,
  });
}

class CategorySaleSummary {
  final String category;
  final double totalRevenue;
  final int itemsCount;

  CategorySaleSummary({
    required this.category,
    required this.totalRevenue,
    required this.itemsCount,
  });
}

class ReportSummary {
  final double totalSales;
  final int totalBills;
  final double totalDiscount;
  final double totalGst;
  final double totalEstimatedProfit;
  final Map<String, double> paymentMethodBreakdown;
  final List<DailySaleSummary> dailySales;
  final List<ProductSaleSummary> topProducts;
  final List<CategorySaleSummary> categorySales;

  ReportSummary({
    required this.totalSales,
    required this.totalBills,
    required this.totalDiscount,
    required this.totalGst,
    required this.totalEstimatedProfit,
    required this.paymentMethodBreakdown,
    required this.dailySales,
    required this.topProducts,
    required this.categorySales,
  });

  bool get isEmpty => totalBills == 0;
}

class ReportRepository {
  final DatabaseHelper _db;

  ReportRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  ReportSummary generateReport({String? storeId, DateTime? startDate, DateTime? endDate}) {
    final allSales = _db.getAllSales(storeId: storeId);

    final filteredSales = allSales.where((s) {
      if (startDate != null && s.createdAt.isBefore(startDate)) return false;
      if (endDate != null && s.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList();

    double totalSales = 0.0;
    double totalDiscount = 0.0;
    double totalGst = 0.0;
    double totalProfit = 0.0;
    final Map<String, double> paymentMethods = {};
    final Map<String, Map<String, dynamic>> productStats = {};
    final Map<String, Map<String, dynamic>> categoryStats = {};
    final Map<String, Map<String, dynamic>> dailyMap = {};

    for (var sale in filteredSales) {
      totalSales += sale.grandTotal;
      totalDiscount += sale.totalDiscount;
      totalGst += sale.totalGst;

      // Payment method
      final method = sale.paymentMethod;
      paymentMethods[method] = (paymentMethods[method] ?? 0.0) + sale.grandTotal;

      // Daily grouping
      final dateKey = '${sale.createdAt.year}-${sale.createdAt.month.toString().padLeft(2, '0')}-${sale.createdAt.day.toString().padLeft(2, '0')}';
      if (!dailyMap.containsKey(dateKey)) {
        dailyMap[dateKey] = {
          'date': DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day),
          'sales': 0.0,
          'bills': 0,
        };
      }
      dailyMap[dateKey]!['sales'] += sale.grandTotal;
      dailyMap[dateKey]!['bills'] += 1;

      // Items calculation
      for (var item in sale.items) {
        final itemRevenue = item.totalAmount;
        final itemCost = item.purchasePrice * item.quantity;
        final itemProfit = itemRevenue - itemCost;
        totalProfit += itemProfit;

        // Product stats
        if (!productStats.containsKey(item.productId)) {
          productStats[item.productId] = {
            'id': item.productId,
            'name': item.productName,
            'qty': 0.0,
            'revenue': 0.0,
            'profit': 0.0,
          };
        }
        productStats[item.productId]!['qty'] += item.quantity;
        productStats[item.productId]!['revenue'] += itemRevenue;
        productStats[item.productId]!['profit'] += itemProfit;

        // Category stats lookup
        final product = _db.getProductById(item.productId, storeId: storeId);
        final catName = product?.category ?? 'General';
        if (!categoryStats.containsKey(catName)) {
          categoryStats[catName] = {
            'name': catName,
            'revenue': 0.0,
            'count': 0,
          };
        }
        categoryStats[catName]!['revenue'] += itemRevenue;
        categoryStats[catName]!['count'] += 1;
      }
    }

    final topProducts = productStats.values.map((v) {
      return ProductSaleSummary(
        productId: v['id'],
        productName: v['name'],
        quantitySold: v['qty'],
        totalRevenue: v['revenue'],
        totalProfit: v['profit'],
      );
    }).toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final categorySales = categoryStats.values.map((v) {
      return CategorySaleSummary(
        category: v['name'],
        totalRevenue: v['revenue'],
        itemsCount: v['count'],
      );
    }).toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final dailySales = dailyMap.values.map((v) {
      return DailySaleSummary(
        date: v['date'],
        totalSales: v['sales'],
        totalBills: v['bills'],
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return ReportSummary(
      totalSales: totalSales,
      totalBills: filteredSales.length,
      totalDiscount: totalDiscount,
      totalGst: totalGst,
      totalEstimatedProfit: totalProfit,
      paymentMethodBreakdown: paymentMethods,
      dailySales: dailySales,
      topProducts: topProducts,
      categorySales: categorySales,
    );
  }

  String exportReportToCsv(ReportSummary report, String title) {
    final buffer = StringBuffer();
    buffer.writeln('SCANZO Business Performance Report: $title');
    buffer.writeln('Generated on: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Summary Metrics');
    buffer.writeln('Total Sales,${report.totalSales.toStringAsFixed(2)}');
    buffer.writeln('Total Bills,${report.totalBills}');
    buffer.writeln('Total Discount,${report.totalDiscount.toStringAsFixed(2)}');
    buffer.writeln('Total Tax / GST,${report.totalGst.toStringAsFixed(2)}');
    buffer.writeln('Estimated Gross Profit,${report.totalEstimatedProfit.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Top Products Sold');
    buffer.writeln('Product Name,Qty Sold,Revenue,Profit');
    for (var p in report.topProducts) {
      buffer.writeln('"${p.productName}",${p.quantitySold},${p.totalRevenue.toStringAsFixed(2)},${p.totalProfit.toStringAsFixed(2)}');
    }
    buffer.writeln('');
    buffer.writeln('Category Sales');
    buffer.writeln('Category,Revenue,Items Sold');
    for (var c in report.categorySales) {
      buffer.writeln('"${c.category}",${c.totalRevenue.toStringAsFixed(2)},${c.itemsCount}');
    }
    return buffer.toString();
  }
}
