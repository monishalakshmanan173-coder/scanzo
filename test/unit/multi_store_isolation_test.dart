import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/customer.dart';
import 'package:scanzo/data/models/sale_item.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/repositories/business_repository.dart';
import 'package:scanzo/data/repositories/product_repository.dart';
import 'package:scanzo/data/repositories/billing_repository.dart';
import 'package:scanzo/data/repositories/inventory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Store Isolation and Shop Type Tests', () {
    late DatabaseHelper db;
    late BusinessRepository businessRepo;
    late ProductRepository productRepo;
    late BillingRepository billingRepo;
    late InventoryRepository inventoryRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();

      businessRepo = BusinessRepository(db: db);
      productRepo = ProductRepository(db: db);
      billingRepo = BillingRepository(db: db);
      inventoryRepo = InventoryRepository(db: db);
    });

    test('Creating different shop types produces isolated stores with tailored categories', () async {
      // 1. Create Electronics Store
      final elecStore = await businessRepo.createOrGetStoreForShopType('electronics', storeName: 'Tech Zone');
      expect(elecStore.shopTypeId, 'electronics');
      expect(businessRepo.activeStoreId, elecStore.id);

      final elecCategories = productRepo.getAllCategories();
      expect(elecCategories.any((c) => c.name.contains('Audio')), true);
      expect(elecCategories.any((c) => c.name.contains('Mobiles')), true);

      // 2. Create Pharmacy Store
      final pharmaStore = await businessRepo.createOrGetStoreForShopType('medical', storeName: 'Apollo Care');
      expect(pharmaStore.shopTypeId, 'medical');
      expect(businessRepo.activeStoreId, pharmaStore.id);

      final pharmaCategories = productRepo.getAllCategories();
      expect(pharmaCategories.any((c) => c.name.contains('Medicines')), true);
      expect(pharmaCategories.any((c) => c.name.contains('Vitamins')), true);

      // 3. Create Fashion Boutique
      final fashionStore = await businessRepo.createOrGetStoreForShopType('clothing', storeName: 'Vogue Boutique');
      expect(fashionStore.shopTypeId, 'clothing');

      final fashionCategories = productRepo.getAllCategories();
      expect(fashionCategories.any((c) => c.name.contains('Menswear') || c.name.contains('Womenswear')), true);

      // 4. Stores list contains all created stores
      final stores = businessRepo.getAllStores();
      expect(stores.length >= 3, true);
    });

    test('Products are strictly isolated between stores with zero data leakage', () async {
      // Setup Store 1: Electronics
      final elecStore = await businessRepo.createOrGetStoreForShopType('electronics', storeName: 'City Gadgets');
      await businessRepo.setActiveStore(elecStore.id);

      final elecProduct = Product(
        id: 'p_headphone',
        storeId: elecStore.id,
        sku: 'SKU-ELEC-1',
        barcode: '8900000000001',
        name: 'Wireless Bluetooth Headset',
        category: 'Audio & Headphones',
        purchasePrice: 1500.0,
        sellingPrice: 2499.0,
        mrp: 2999.0,
        currentStock: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(elecProduct);

      expect(productRepo.getAllProducts().length, 1);
      expect(productRepo.getAllProducts().first.name, 'Wireless Bluetooth Headset');

      // Setup Store 2: Pharmacy / Medical
      final medStore = await businessRepo.createOrGetStoreForShopType('medical', storeName: 'City Chemist');
      await businessRepo.setActiveStore(medStore.id);

      // Verify Pharmacy store starts with 0 products
      expect(productRepo.getAllProducts().isEmpty, true);
      expect(productRepo.getProductByBarcode('8900000000001'), isNull);

      final medProduct = Product(
        id: 'p_paracetamol',
        storeId: medStore.id,
        sku: 'SKU-MED-1',
        barcode: '8900000000002',
        name: 'Paracetamol 650mg 10s',
        category: 'Medicines',
        purchasePrice: 18.0,
        sellingPrice: 32.0,
        mrp: 35.0,
        currentStock: 50.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(medProduct);

      expect(productRepo.getAllProducts().length, 1);
      expect(productRepo.getAllProducts().first.name, 'Paracetamol 650mg 10s');
      expect(productRepo.getProductByBarcode('8900000000002')?.name, 'Paracetamol 650mg 10s');

      // Switch back to Electronics Store
      await businessRepo.setActiveStore(elecStore.id);

      // Verify Electronics store sees ONLY its headphone product, not paracetamol
      final activeElecProducts = productRepo.getAllProducts();
      expect(activeElecProducts.length, 1);
      expect(activeElecProducts.first.name, 'Wireless Bluetooth Headset');
      expect(productRepo.getProductByBarcode('8900000000002'), isNull);
      expect(productRepo.getProductByBarcode('8900000000001')?.name, 'Wireless Bluetooth Headset');
    });

    test('Checkout sales, invoices, and valuation remain strictly separated per store', () async {
      // 1. Electronics Store setup & sale
      final elecStore = await businessRepo.createOrGetStoreForShopType('electronics', storeName: 'Digital World');
      await businessRepo.setActiveStore(elecStore.id);

      final phone = Product(
        id: 'p_phone',
        storeId: elecStore.id,
        sku: 'SKU-PHN',
        barcode: '8909000000001',
        name: 'Smart Phone 5G',
        category: 'Mobiles & Gadgets',
        purchasePrice: 12000.0,
        sellingPrice: 18000.0,
        mrp: 19999.0,
        currentStock: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await productRepo.saveProduct(phone);

      final saleItem = SaleItem(
        id: 'si_phn_1',
        saleId: '',
        productId: phone.id,
        productName: phone.name,
        barcode: phone.barcode,
        quantity: 1.0,
        unit: 'Pcs',
        unitPrice: 18000.0,
        purchasePrice: 12000.0,
        discountAmount: 0.0,
        gstRate: 18.0,
        gstAmount: 2745.76,
        totalAmount: 18000.0,
      );

      final elecSale = await billingRepo.processCheckout(
        customerId: null,
        customerName: 'Kavitha R',
        customerMobile: '9988776655',
        items: [saleItem],
        subtotal: 18000.0,
        totalDiscount: 0.0,
        totalGst: 2745.76,
        grandTotal: 18000.0,
        paymentMethod: 'UPI',
        paidAmount: 18000.0,
        changeAmount: 0.0,
      );

      expect(elecSale.storeId, elecStore.id);
      expect(elecSale.grandTotal, 18000.0);
      expect(billingRepo.getAllSales().length, 1);
      expect(productRepo.getProductById(phone.id)?.currentStock, 4.0);
      expect(inventoryRepo.getTotalStockValuation(), 4.0 * 12000.0);

      // 2. Switch to Fashion Store
      final fashionStore = await businessRepo.createOrGetStoreForShopType('clothing', storeName: 'Silk & Cotton');
      await businessRepo.setActiveStore(fashionStore.id);

      // In Fashion Store: sales should be 0, valuation 0
      expect(billingRepo.getAllSales().length, 0);
      expect(inventoryRepo.getTotalStockValuation(), 0.0);
      expect(productRepo.getAllProducts().length, 0);

      // Switch back to Electronics: sales should still be 1 with exact records
      await businessRepo.setActiveStore(elecStore.id);
      expect(billingRepo.getAllSales().length, 1);
      expect(billingRepo.getAllSales().first.customerName, 'Kavitha R');
      expect(inventoryRepo.getTotalStockValuation(), 48000.0);
    });

    test('Customers and credit balances belong only to their respective stores', () async {
      final storeA = await businessRepo.createOrGetStoreForShopType('retail', storeName: 'Corner Store');
      await businessRepo.setActiveStore(storeA.id);

      final customerA = Customer(
        id: 'c_retail_1',
        storeId: storeA.id,
        name: 'Gopal Krishna',
        mobile: '9845012345',
        pendingBalance: 500.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveCustomer(customerA);

      expect(db.getAllCustomers().length, 1);
      expect(db.getAllCustomers().first.name, 'Gopal Krishna');

      // Switch to Bakery
      final storeB = await businessRepo.createOrGetStoreForShopType('bakery', storeName: 'Sweet Tooth Bakery');
      await businessRepo.setActiveStore(storeB.id);

      // Customer A should not leak into Bakery
      expect(db.getAllCustomers().length, 0);

      final customerB = Customer(
        id: 'c_bakery_1',
        storeId: storeB.id,
        name: 'Maria Fernandez',
        mobile: '9741098765',
        pendingBalance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveCustomer(customerB);

      expect(db.getAllCustomers().length, 1);
      expect(db.getAllCustomers().first.name, 'Maria Fernandez');

      // Switch back to Store A
      await businessRepo.setActiveStore(storeA.id);
      expect(db.getAllCustomers().length, 1);
      expect(db.getAllCustomers().first.name, 'Gopal Krishna');
    });
  });
}
