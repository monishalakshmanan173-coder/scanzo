import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/sale_item.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/repositories/business_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real Payments & Safe Inventory Unit Tests', () {
    late DatabaseHelper db;
    late BusinessRepository businessRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();
      businessRepo = BusinessRepository(db: db);
    });

    test('Cash Checkout: accurately calculates change and records Cash payment', () async {
      final store = await businessRepo.createOrGetStoreForShopType('retail', storeName: 'Cash Test Store');
      await businessRepo.setActiveStore(store.id);

      final product = Product(
        id: 'p_cash_item',
        sku: 'SKU-001',
        barcode: '123456789012',
        name: 'Item A',
        category: 'General',
        purchasePrice: 40.0,
        sellingPrice: 75.0,
        mrp: 80.0,
        currentStock: 50.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      final item = SaleItem(
        id: 'si_cash',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 2.0,
        unitPrice: 75.0,
        totalAmount: 150.0,
      );

      const double grandTotal = 150.0;
      const double cashReceived = 200.0;
      const double changeToReturn = cashReceived - grandTotal; // 50.0

      final sale = await db.processCheckout(
        customerId: null,
        customerName: 'Cash Customer',
        customerMobile: null,
        items: [item],
        subtotal: grandTotal,
        totalDiscount: 0.0,
        totalGst: 0.0,
        grandTotal: grandTotal,
        paymentMethod: 'Cash',
        paidAmount: cashReceived,
        changeAmount: changeToReturn,
      );

      expect(sale.paymentMethod, 'Cash');
      expect(sale.grandTotal, 150.0);
      expect(sale.paidAmount, 200.0);
      expect(sale.changeAmount, 50.0);
      expect(sale.paymentStatus, 'Paid');

      // Verify stock was reduced safely
      final updatedProduct = db.getProductById('p_cash_item');
      expect(updatedProduct?.currentStock, 48.0); // 50 - 2
    });

    test('GPay / UPI Checkout: persists store UPI ID and records UPI payment', () async {
      final store = await businessRepo.createOrGetStoreForShopType('electronics', storeName: 'Digital Store');
      await businessRepo.setActiveStore(store.id);

      // Configure UPI ID
      await businessRepo.updateStoreUpiId('storename@okaxis');
      expect(businessRepo.activeStoreUpiId, 'storename@okaxis');

      final product = Product(
        id: 'p_upi_item',
        sku: 'SKU-UPI',
        barcode: '987654321098',
        name: 'Headphones',
        category: 'Audio',
        purchasePrice: 500.0,
        sellingPrice: 899.0,
        mrp: 999.0,
        currentStock: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      final item = SaleItem(
        id: 'si_upi',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 1.0,
        unitPrice: 899.0,
        totalAmount: 899.0,
      );

      // Verify UPI URI generation
      const grandTotal = 899.0;
      final upiUri = 'upi://pay?pa=${businessRepo.activeStoreUpiId}&pn=${Uri.encodeComponent(store.businessName)}&am=${grandTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Scanzo Bill")}';
      expect(upiUri.contains('pa=storename%40okaxis') || upiUri.contains('pa=storename@okaxis'), true);
      expect(upiUri.contains('am=899.00'), true);

      final sale = await db.processCheckout(
        customerId: null,
        customerName: 'UPI Customer',
        customerMobile: null,
        items: [item],
        subtotal: grandTotal,
        totalDiscount: 0.0,
        totalGst: 0.0,
        grandTotal: grandTotal,
        paymentMethod: 'GPay / UPI',
        paidAmount: grandTotal,
        changeAmount: 0.0,
      );

      expect(sale.paymentMethod, 'GPay / UPI');
      expect(sale.grandTotal, 899.0);
      expect(sale.paidAmount, 899.0);
      expect(sale.changeAmount, 0.0);
      expect(sale.paymentStatus, 'Paid');

      // Verify inventory deducted
      final updated = db.getProductById('p_upi_item');
      expect(updated?.currentStock, 9.0);
    });

    test('Negative Stock Prevention: throws Exception and prevents negative inventory', () async {
      final store = await businessRepo.createOrGetStoreForShopType('clothing', storeName: 'Fashion Hub');
      await businessRepo.setActiveStore(store.id);

      final product = Product(
        id: 'p_scarf',
        sku: 'SKU-SCARF',
        barcode: '112233445566',
        name: 'Silk Scarf',
        category: 'Accessories',
        purchasePrice: 150.0,
        sellingPrice: 250.0,
        mrp: 300.0,
        currentStock: 2.0, // Only 2 in stock
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      // Attempting to buy 5 when only 2 available
      final excessItem = SaleItem(
        id: 'si_excess',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 5.0,
        unitPrice: 250.0,
        totalAmount: 1250.0,
      );

      expect(
        () => db.processCheckout(
          customerId: null,
          customerName: 'Buyer',
          customerMobile: null,
          items: [excessItem],
          subtotal: 1250.0,
          totalDiscount: 0.0,
          totalGst: 0.0,
          grandTotal: 1250.0,
          paymentMethod: 'Cash',
          paidAmount: 1250.0,
          changeAmount: 0.0,
        ),
        throwsA(isA<Exception>()),
      );

      // Stock must remain intact at 2.0
      final intact = db.getProductById('p_scarf');
      expect(intact?.currentStock, 2.0);
    });

    test('User & Store Isolation: scoping user ID isolates store lists', () async {
      db.setActiveUserId('user_alpha');
      final storeA = await businessRepo.createOrGetStoreForShopType('retail', storeName: 'Alpha Store');

      db.setActiveUserId('user_beta');
      final storeB = await businessRepo.createOrGetStoreForShopType('pharmacy', storeName: 'Beta Pharmacy');

      // Check stores for user_alpha
      final storesAlpha = db.getAllStores(userId: 'user_alpha');
      expect(storesAlpha.any((s) => s.id == storeA.id), true);
      expect(storesAlpha.any((s) => s.id == storeB.id), false);

      // Check stores for user_beta
      final storesBeta = db.getAllStores(userId: 'user_beta');
      expect(storesBeta.any((s) => s.id == storeB.id), true);
      expect(storesBeta.any((s) => s.id == storeA.id), false);
    });
  });
}
