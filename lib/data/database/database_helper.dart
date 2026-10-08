import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/payment.dart';
import '../models/stock_movement.dart';
import '../models/invoice.dart';
import '../models/app_settings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/id_generator.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  bool _initialized = false;

  // In-memory collections cached from persistent store
  final Map<String, Product> _products = {};
  final Map<String, ProductCategory> _categories = {};
  final Map<String, Supplier> _suppliers = {};
  final Map<String, Customer> _customers = {};
  final Map<String, Sale> _sales = {};
  final List<SaleItem> _saleItems = [];
  final List<Payment> _payments = [];
  final List<StockMovement> _stockMovements = [];
  final Map<String, Invoice> _invoices = {};
  BusinessProfile? _businessProfile;
  AppSettings? _appSettings;
  int _invoiceSequence = 0;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Business Profile
      final businessJson = prefs.getString(AppConstants.keyActiveBusiness);
      if (businessJson != null && businessJson.isNotEmpty) {
        _businessProfile = BusinessProfile.fromMap(jsonDecode(businessJson));
      }

      // Load Settings
      final settingsJson = prefs.getString(AppConstants.keyAppSettings);
      if (settingsJson != null && settingsJson.isNotEmpty) {
        _appSettings = AppSettings.fromMap(jsonDecode(settingsJson));
      } else {
        _appSettings = AppSettings(
          id: 'default_settings',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      // Load collections from persistent storage
      await _loadCollections(prefs);

      _initialized = true;
    } catch (e) {
      debugPrint('DatabaseHelper init error: $e');
      _initialized = true; // allow app to continue gracefully
    }
  }

  Future<void> _loadCollections(SharedPreferences prefs) async {
    // Products
    final productsStr = prefs.getString('db_products');
    if (productsStr != null) {
      final List list = jsonDecode(productsStr);
      for (var item in list) {
        final p = Product.fromMap(item);
        _products[p.id] = p;
      }
    }

    // Categories
    final categoriesStr = prefs.getString('db_categories');
    if (categoriesStr != null) {
      final List list = jsonDecode(categoriesStr);
      for (var item in list) {
        final c = ProductCategory.fromMap(item);
        _categories[c.id] = c;
      }
    } else {
      // Default initial standard categories
      _seedDefaultCategories();
    }

    // Customers
    final customersStr = prefs.getString('db_customers');
    if (customersStr != null) {
      final List list = jsonDecode(customersStr);
      for (var item in list) {
        final c = Customer.fromMap(item);
        _customers[c.id] = c;
      }
    }

    // Suppliers
    final suppliersStr = prefs.getString('db_suppliers');
    if (suppliersStr != null) {
      final List list = jsonDecode(suppliersStr);
      for (var item in list) {
        final s = Supplier.fromMap(item);
        _suppliers[s.id] = s;
      }
    }

    // Sales & SaleItems
    final salesStr = prefs.getString('db_sales');
    final saleItemsStr = prefs.getString('db_sale_items');
    if (saleItemsStr != null) {
      final List list = jsonDecode(saleItemsStr);
      _saleItems.clear();
      for (var item in list) {
        _saleItems.add(SaleItem.fromMap(item));
      }
    }

    if (salesStr != null) {
      final List list = jsonDecode(salesStr);
      for (var item in list) {
        final sId = item['id'];
        final items = _saleItems.where((si) => si.saleId == sId).toList();
        final s = Sale.fromMap(item, items);
        _sales[s.id] = s;
      }
    }

    // Payments
    final paymentsStr = prefs.getString('db_payments');
    if (paymentsStr != null) {
      final List list = jsonDecode(paymentsStr);
      _payments.clear();
      for (var item in list) {
        _payments.add(Payment.fromMap(item));
      }
    }

    // Stock Movements
    final movementsStr = prefs.getString('db_stock_movements');
    if (movementsStr != null) {
      final List list = jsonDecode(movementsStr);
      _stockMovements.clear();
      for (var item in list) {
        _stockMovements.add(StockMovement.fromMap(item));
      }
    }

    // Invoices
    final invoicesStr = prefs.getString('db_invoices');
    if (invoicesStr != null) {
      final List list = jsonDecode(invoicesStr);
      for (var item in list) {
        final inv = Invoice.fromMap(item);
        _invoices[inv.id] = inv;
      }
    }

    // Sequence
    _invoiceSequence = prefs.getInt('db_invoice_sequence') ?? _sales.length;
  }

  void _seedDefaultCategories() {
    final defaultNames = ['General', 'Groceries', 'Beverages', 'Dairy', 'Snacks', 'Bakery', 'Clothing', 'Electronics'];
    for (var name in defaultNames) {
      final id = 'cat_${name.toLowerCase()}';
      _categories[id] = ProductCategory(
        id: id,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // --- PERSISTENCE HELPERS ---
  Future<void> _persistProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _products.values.map((p) => p.toMap()).toList();
    await prefs.setString('db_products', jsonEncode(list));
  }

  Future<void> _persistCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _categories.values.map((c) => c.toMap()).toList();
    await prefs.setString('db_categories', jsonEncode(list));
  }

  Future<void> _persistCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _customers.values.map((c) => c.toMap()).toList();
    await prefs.setString('db_customers', jsonEncode(list));
  }

  Future<void> _persistSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _suppliers.values.map((s) => s.toMap()).toList();
    await prefs.setString('db_suppliers', jsonEncode(list));
  }

  Future<void> _persistSalesAndStock() async {
    final prefs = await SharedPreferences.getInstance();
    final sList = _sales.values.map((s) => s.toMap()).toList();
    final siList = _saleItems.map((si) => si.toMap()).toList();
    final pList = _payments.map((p) => p.toMap()).toList();
    final smList = _stockMovements.map((sm) => sm.toMap()).toList();
    final invList = _invoices.values.map((inv) => inv.toMap()).toList();

    await prefs.setString('db_sales', jsonEncode(sList));
    await prefs.setString('db_sale_items', jsonEncode(siList));
    await prefs.setString('db_payments', jsonEncode(pList));
    await prefs.setString('db_stock_movements', jsonEncode(smList));
    await prefs.setString('db_invoices', jsonEncode(invList));
    await prefs.setInt('db_invoice_sequence', _invoiceSequence);
    await _persistProducts();
  }

  // --- BUSINESS PROFILE ---
  BusinessProfile? get businessProfile => _businessProfile;

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    _businessProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyActiveBusiness, jsonEncode(profile.toMap()));
    await prefs.setBool(AppConstants.keyBusinessSetupCompleted, true);
  }

  // --- SETTINGS ---
  AppSettings get appSettings =>
      _appSettings ??
      AppSettings(
        id: 'default_settings',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<void> saveAppSettings(AppSettings settings) async {
    _appSettings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAppSettings, jsonEncode(settings.toMap()));
  }

  // --- PRODUCTS ---
  List<Product> getAllProducts() {
    return _products.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Product? getProductById(String id) => _products[id];

  Product? getProductByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return null;
    try {
      return _products.values.firstWhere(
        (p) => p.barcode.trim().toLowerCase() == barcode.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProduct(Product product) async {
    _products[product.id] = product;
    await _persistProducts();
  }

  Future<void> bulkInsertProducts(List<Product> newProducts) async {
    for (var p in newProducts) {
      _products[p.id] = p;
    }
    await _persistProducts();
  }

  Future<void> deleteProduct(String id) async {
    _products.remove(id);
    await _persistProducts();
  }

  List<Product> getLowStockProducts() {
    return _products.values.where((p) => p.isLowStock || p.isOutOfStock).toList();
  }

  // --- CATEGORIES ---
  List<ProductCategory> getAllCategories() => _categories.values.toList();

  Future<void> saveCategory(ProductCategory category) async {
    _categories[category.id] = category;
    await _persistCategories();
  }

  Future<void> deleteCategory(String id) async {
    _categories.remove(id);
    await _persistCategories();
  }

  // --- CUSTOMERS ---
  List<Customer> getAllCustomers() {
    return _customers.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Customer? getCustomerById(String id) => _customers[id];

  Future<void> saveCustomer(Customer customer) async {
    _customers[customer.id] = customer;
    await _persistCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    _customers.remove(id);
    await _persistCustomers();
  }

  // --- SUPPLIERS ---
  List<Supplier> getAllSuppliers() {
    return _suppliers.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Supplier? getSupplierById(String id) => _suppliers[id];

  Future<void> saveSupplier(Supplier supplier) async {
    _suppliers[supplier.id] = supplier;
    await _persistSuppliers();
  }

  Future<void> deleteSupplier(String id) async {
    _suppliers.remove(id);
    await _persistSuppliers();
  }

  // --- BILLING / TRANSACTIONAL CHECKOUT ---
  int getNextInvoiceSequence() {
    return _invoiceSequence + 1;
  }

  String generateNextInvoiceNumber() {
    final prefix = _businessProfile?.invoicePrefix ?? _appSettings?.invoicePrefix ?? AppConstants.defaultInvoicePrefix;
    return IdGenerator.generateInvoiceNumber(prefix, getNextInvoiceSequence());
  }

  Future<Sale> processCheckout({
    required String? customerId,
    required String? customerName,
    required String? customerMobile,
    required List<SaleItem> items,
    required double subtotal,
    required double totalDiscount,
    required double totalGst,
    required double grandTotal,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cannot process checkout with empty cart.');
    }

    _invoiceSequence++;
    final prefix = _businessProfile?.invoicePrefix ?? _appSettings?.invoicePrefix ?? AppConstants.defaultInvoicePrefix;
    final invoiceNumber = IdGenerator.generateInvoiceNumber(prefix, _invoiceSequence);
    final saleId = IdGenerator.generateId('sale');
    final now = DateTime.now();

    // 1. Create Sale Items & Deduct Stock
    final processedItems = <SaleItem>[];
    for (var item in items) {
      final processedItem = SaleItem(
        id: IdGenerator.generateId('sitem'),
        saleId: saleId,
        productId: item.productId,
        productName: item.productName,
        barcode: item.barcode,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        purchasePrice: item.purchasePrice,
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        gstAmount: item.gstAmount,
        totalAmount: item.totalAmount,
      );
      processedItems.add(processedItem);
      _saleItems.add(processedItem);

      // Stock Deduction and Movement
      final product = _products[item.productId];
      if (product != null) {
        final prevStock = product.currentStock;
        final newStock = prevStock - item.quantity;
        _products[product.id] = product.copyWith(currentStock: newStock);

        _stockMovements.add(StockMovement(
          id: IdGenerator.generateId('mov'),
          productId: product.id,
          productName: product.name,
          type: AppConstants.stockMovementSale,
          quantityDelta: -item.quantity,
          previousStock: prevStock,
          newStock: newStock,
          referenceId: saleId,
          reason: 'Sold on Invoice $invoiceNumber',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    // 2. Create Sale
    final sale = Sale(
      id: saleId,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      customerMobile: customerMobile,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      totalGst: totalGst,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      paymentStatus: paidAmount >= grandTotal ? 'Paid' : 'Partial',
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      notes: notes,
      items: processedItems,
      createdAt: now,
      updatedAt: now,
    );
    _sales[sale.id] = sale;

    // 3. Create Payment record
    _payments.add(Payment(
      id: IdGenerator.generateId('pay'),
      saleId: sale.id,
      amount: paidAmount > grandTotal ? grandTotal : paidAmount,
      paymentMethod: paymentMethod,
      status: 'Completed',
      createdAt: now,
      updatedAt: now,
    ));

    // 4. Create Invoice
    final invoice = Invoice(
      id: IdGenerator.generateId('inv'),
      invoiceNumber: invoiceNumber,
      saleId: sale.id,
      customerName: customerName,
      customerMobile: customerMobile,
      businessName: _businessProfile?.businessName ?? 'SCANZO Store',
      businessGstin: _businessProfile?.gstin,
      businessAddress: _businessProfile?.address ?? '',
      businessMobile: _businessProfile?.mobile ?? '',
      subtotal: subtotal,
      discount: totalDiscount,
      gst: totalGst,
      total: grandTotal,
      paymentMethod: paymentMethod,
      format: _appSettings?.defaultReceiptFormat ?? 'Standard Invoice',
      createdAt: now,
      updatedAt: now,
    );
    _invoices[invoice.id] = invoice;

    // 5. Update Customer pending balance if partially paid
    if (customerId != null && _customers.containsKey(customerId)) {
      final cust = _customers[customerId]!;
      final balanceDelta = grandTotal - paidAmount;
      if (balanceDelta > 0) {
        _customers[customerId] = cust.copyWith(
          pendingBalance: cust.pendingBalance + balanceDelta,
        );
        await _persistCustomers();
      }
    }

    // Persist all data atomically
    await _persistSalesAndStock();

    return sale;
  }

  // --- SALES QUERIES ---
  List<Sale> getAllSales() {
    final list = _sales.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Sale? getSaleById(String id) => _sales[id];

  Invoice? getInvoiceBySaleId(String saleId) {
    try {
      return _invoices.values.firstWhere((inv) => inv.saleId == saleId);
    } catch (_) {
      return null;
    }
  }

  // --- STOCK MOVEMENTS & ADJUSTMENTS ---
  List<StockMovement> getAllStockMovements() {
    return List.from(_stockMovements.reversed);
  }

  Future<void> recordStockAdjustment({
    required String productId,
    required double newStock,
    required String type,
    String? reason,
  }) async {
    final product = _products[productId];
    if (product == null) return;

    final prev = product.currentStock;
    final delta = newStock - prev;
    final now = DateTime.now();

    _products[productId] = product.copyWith(currentStock: newStock);

    _stockMovements.add(StockMovement(
      id: IdGenerator.generateId('adj'),
      productId: productId,
      productName: product.name,
      type: type,
      quantityDelta: delta,
      previousStock: prev,
      newStock: newStock,
      reason: reason ?? 'Manual stock adjustment',
      createdAt: now,
      updatedAt: now,
    ));

    await _persistSalesAndStock();
  }

  // --- BACKUP & RESTORE ---
  String exportFullDatabaseJson() {
    final data = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'business': _businessProfile?.toMap(),
      'settings': _appSettings?.toMap(),
      'products': _products.values.map((p) => p.toMap()).toList(),
      'categories': _categories.values.map((c) => c.toMap()).toList(),
      'customers': _customers.values.map((c) => c.toMap()).toList(),
      'suppliers': _suppliers.values.map((s) => s.toMap()).toList(),
      'sales': _sales.values.map((s) => s.toMap()).toList(),
      'saleItems': _saleItems.map((si) => si.toMap()).toList(),
      'payments': _payments.map((p) => p.toMap()).toList(),
      'stockMovements': _stockMovements.map((sm) => sm.toMap()).toList(),
      'invoices': _invoices.values.map((inv) => inv.toMap()).toList(),
      'invoiceSequence': _invoiceSequence,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importFullDatabaseJson(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);

    if (data['business'] != null) {
      _businessProfile = BusinessProfile.fromMap(data['business']);
    }
    if (data['settings'] != null) {
      _appSettings = AppSettings.fromMap(data['settings']);
    }

    _products.clear();
    if (data['products'] != null) {
      for (var item in data['products']) {
        final p = Product.fromMap(item);
        _products[p.id] = p;
      }
    }

    _categories.clear();
    if (data['categories'] != null) {
      for (var item in data['categories']) {
        final c = ProductCategory.fromMap(item);
        _categories[c.id] = c;
      }
    }

    _customers.clear();
    if (data['customers'] != null) {
      for (var item in data['customers']) {
        final c = Customer.fromMap(item);
        _customers[c.id] = c;
      }
    }

    _suppliers.clear();
    if (data['suppliers'] != null) {
      for (var item in data['suppliers']) {
        final s = Supplier.fromMap(item);
        _suppliers[s.id] = s;
      }
    }

    _saleItems.clear();
    if (data['saleItems'] != null) {
      for (var item in data['saleItems']) {
        _saleItems.add(SaleItem.fromMap(item));
      }
    }

    _sales.clear();
    if (data['sales'] != null) {
      for (var item in data['sales']) {
        final sId = item['id'];
        final items = _saleItems.where((si) => si.saleId == sId).toList();
        final s = Sale.fromMap(item, items);
        _sales[s.id] = s;
      }
    }

    _payments.clear();
    if (data['payments'] != null) {
      for (var item in data['payments']) {
        _payments.add(Payment.fromMap(item));
      }
    }

    _stockMovements.clear();
    if (data['stockMovements'] != null) {
      for (var item in data['stockMovements']) {
        _stockMovements.add(StockMovement.fromMap(item));
      }
    }

    _invoices.clear();
    if (data['invoices'] != null) {
      for (var item in data['invoices']) {
        final inv = Invoice.fromMap(item);
        _invoices[inv.id] = inv;
      }
    }

    _invoiceSequence = data['invoiceSequence'] ?? _sales.length;

    // Persist everything
    await _persistProducts();
    await _persistCategories();
    await _persistCustomers();
    await _persistSuppliers();
    await _persistSalesAndStock();
    if (_businessProfile != null) {
      await saveBusinessProfile(_businessProfile!);
    }
    if (_appSettings != null) {
      await saveAppSettings(_appSettings!);
    }
  }

  // Clear data on reset (not session)
  Future<void> clearAllBusinessData() async {
    _products.clear();
    _customers.clear();
    _suppliers.clear();
    _sales.clear();
    _saleItems.clear();
    _payments.clear();
    _stockMovements.clear();
    _invoices.clear();
    _invoiceSequence = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('db_products');
    await prefs.remove('db_customers');
    await prefs.remove('db_suppliers');
    await prefs.remove('db_sales');
    await prefs.remove('db_sale_items');
    await prefs.remove('db_payments');
    await prefs.remove('db_stock_movements');
    await prefs.remove('db_invoices');
    await prefs.remove('db_invoice_sequence');
    _seedDefaultCategories();
    await _persistCategories();
  }
}
