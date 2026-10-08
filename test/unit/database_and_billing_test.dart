import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/core/constants/app_constants.dart';
import 'package:scanzo/data/models/business_profile.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/customer.dart';
import 'package:scanzo/data/models/sale_item.dart';
import 'package:scanzo/data/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseHelper & Billing Transaction Tests', () {
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();
    });

    test('Product CRUD operations work properly', () async {
      final product = Product(
        id: 'prod_101',
        sku: 'SKU-RICE',
        barcode: '8901111111111',
        name: 'Basmati Rice 1kg',
        category: 'Groceries',
        purchasePrice: 80.0,
        sellingPrice: 110.0,
        mrp: 120.0,
        currentStock: 25.0,
        minStock: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save product
      await db.saveProduct(product);

      expect(db.getAllProducts().length, 1);
      expect(db.getProductById('prod_101')?.name, 'Basmati Rice 1kg');
      expect(db.getProductByBarcode('8901111111111')?.sku, 'SKU-RICE');

      // Update product
      final updated = product.copyWith(sellingPrice: 115.0);
      await db.saveProduct(updated);
      expect(db.getProductById('prod_101')?.sellingPrice, 115.0);

      // Delete product
      await db.deleteProduct('prod_101');
      expect(db.getAllProducts().isEmpty, true);
    });

    test('Checkout transaction decrements stock and creates Sale, Payment, and StockMovement', () async {
      final business = BusinessProfile(
        id: 'biz_1',
        businessName: 'Scanzo Mart',
        ownerName: 'Ajay',
        mobile: '9876543210',
        address: 'MG Road',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560001',
        invoicePrefix: 'SCZ',
        shopTypeId: 'grocery',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveBusinessProfile(business);

      final product = Product(
        id: 'prod_tea',
        sku: 'SKU-TEA',
        barcode: '8902222222222',
        name: 'Assam Tea 250g',
        category: 'Beverages',
        purchasePrice: 70.0,
        sellingPrice: 100.0,
        mrp: 110.0,
        currentStock: 20.0,
        minStock: 4.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      final saleItem = SaleItem(
        id: 'si_1',
        saleId: '',
        productId: product.id,
        productName: product.name,
        barcode: product.barcode,
        quantity: 3.0,
        unit: 'Pcs',
        unitPrice: 100.0,
        purchasePrice: 70.0,
        discountAmount: 0.0,
        gstRate: 5.0,
        gstAmount: 15.0,
        totalAmount: 315.0,
      );

      final sale = await db.processCheckout(
        customerId: null,
        customerName: 'Walk-in',
        customerMobile: null,
        items: [saleItem],
        subtotal: 300.0,
        totalDiscount: 0.0,
        totalGst: 15.0,
        grandTotal: 315.0,
        paymentMethod: 'Cash',
        paidAmount: 350.0,
        changeAmount: 35.0,
      );

      // Verify Sale details
      expect(sale.grandTotal, 315.0);
      expect(sale.invoiceNumber.contains('SCZ-'), true);
      expect(sale.paymentStatus, 'Paid');

      // Verify Stock decrement
      final updatedProduct = db.getProductById('prod_tea');
      expect(updatedProduct?.currentStock, 17.0); // 20 - 3

      // Verify StockMovement recorded
      final movements = db.getAllStockMovements();
      expect(movements.isNotEmpty, true);
      expect(movements.first.type, AppConstants.stockMovementSale);
      expect(movements.first.quantityDelta, -3.0);
      expect(movements.first.previousStock, 20.0);
      expect(movements.first.newStock, 17.0);

      // Verify Invoice created
      final invoice = db.getInvoiceBySaleId(sale.id);
      expect(invoice, isNotNull);
      expect(invoice?.invoiceNumber, sale.invoiceNumber);
      expect(invoice?.total, 315.0);
    });

    test('Checkout throws exception when attempting to checkout an empty cart', () async {
      expect(
        () => db.processCheckout(
          customerId: null,
          customerName: null,
          customerMobile: null,
          items: [],
          subtotal: 0,
          totalDiscount: 0,
          totalGst: 0,
          grandTotal: 0,
          paymentMethod: 'Cash',
          paidAmount: 0,
          changeAmount: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Customer pending balance increases when bill is partially paid', () async {
      final customer = Customer(
        id: 'cust_ramesh',
        name: 'Ramesh',
        mobile: '9876543210',
        pendingBalance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveCustomer(customer);

      final product = Product(
        id: 'p_milk',
        sku: 'SKU-MILK',
        barcode: '8903333333333',
        name: 'Fresh Milk 1L',
        category: 'Dairy',
        purchasePrice: 40.0,
        sellingPrice: 50.0,
        mrp: 50.0,
        currentStock: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      final saleItem = SaleItem(
        id: 'si_2',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 2.0,
        unitPrice: 50.0,
        totalAmount: 100.0,
      );

      // Bill is 100.0, but customer only pays 60.0
      await db.processCheckout(
        customerId: customer.id,
        customerName: customer.name,
        customerMobile: customer.mobile,
        items: [saleItem],
        subtotal: 100.0,
        totalDiscount: 0.0,
        totalGst: 0.0,
        grandTotal: 100.0,
        paymentMethod: 'Cash',
        paidAmount: 60.0,
        changeAmount: 0.0,
      );

      final updatedCustomer = db.getCustomerById('cust_ramesh');
      expect(updatedCustomer?.pendingBalance, 40.0); // 100 - 60
    });
  });
}
