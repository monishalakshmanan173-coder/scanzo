import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/sale_item.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/repositories/report_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportRepository Tests - NO FAKE DATA', () {
    late DatabaseHelper db;
    late ReportRepository reportRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();
      reportRepo = ReportRepository(db: db);
    });

    test('Empty database yields zero metrics and empty report state - strictly NO fake data', () {
      final report = reportRepo.generateReport();

      expect(report.totalSales, 0.0);
      expect(report.totalBills, 0);
      expect(report.totalDiscount, 0.0);
      expect(report.totalGst, 0.0);
      expect(report.totalEstimatedProfit, 0.0);
      expect(report.dailySales.isEmpty, true);
      expect(report.topProducts.isEmpty, true);
      expect(report.categorySales.isEmpty, true);
      expect(report.isEmpty, true);
    });

    test('Reports correctly aggregate real sales and gross profit', () async {
      final product = Product(
        id: 'p_biscuit',
        sku: 'SKU-BIS',
        barcode: '8904444444444',
        name: 'Oat Cookies',
        category: 'Snacks',
        purchasePrice: 20.0,
        sellingPrice: 30.0,
        mrp: 30.0,
        currentStock: 50.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      final saleItem = SaleItem(
        id: 'si_bis',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 5.0,
        unitPrice: 30.0,
        purchasePrice: 20.0,
        totalAmount: 150.0,
      );

      await db.processCheckout(
        customerId: null,
        customerName: null,
        customerMobile: null,
        items: [saleItem],
        subtotal: 150.0,
        totalDiscount: 10.0,
        totalGst: 0.0,
        grandTotal: 140.0,
        paymentMethod: 'UPI',
        paidAmount: 140.0,
        changeAmount: 0.0,
      );

      final report = reportRepo.generateReport();

      expect(report.totalSales, 140.0);
      expect(report.totalBills, 1);
      expect(report.totalDiscount, 10.0);
      // Item Revenue is 150, cost is 5 * 20 = 100, profit is 50
      expect(report.totalEstimatedProfit, 50.0);
      expect(report.paymentMethodBreakdown['UPI'], 140.0);
      expect(report.topProducts.first.productName, 'Oat Cookies');
      expect(report.topProducts.first.quantitySold, 5.0);
      expect(report.categorySales.first.category, 'Snacks');

      // Test CSV Export
      final csv = reportRepo.exportReportToCsv(report, 'Test Report');
      expect(csv.contains('SCANZO Business Performance Report: Test Report'), true);
      expect(csv.contains('Oat Cookies'), true);
      expect(csv.contains('140.00'), true);
    });
  });
}
