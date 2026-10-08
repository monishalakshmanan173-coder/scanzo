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
import '../models/shop_type.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/id_generator.dart';
import '../services/cloud_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  bool _initialized = false;

  // Multi-store management
  final Map<String, BusinessProfile> _stores = {};
  final Map<String, BusinessProfile> _allKnownStores = {};
  String _activeStoreId = '';

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

      if (_activeUserId.isNotEmpty) {
        await setActiveUserId(_activeUserId);
      } else {
        // Load legacy stores if any
        final storesStr = prefs.getString('db_stores');
        if (storesStr != null && storesStr.isNotEmpty) {
          final List list = jsonDecode(storesStr);
          for (var item in list) {
            final profile = BusinessProfile.fromMap(item);
            _allKnownStores[profile.id] = profile;
            _stores[profile.id] = profile;
          }
        }
        final businessJson = prefs.getString(AppConstants.keyActiveBusiness);
        if (businessJson != null && businessJson.isNotEmpty) {
          final profile = BusinessProfile.fromMap(jsonDecode(businessJson));
          _allKnownStores[profile.id] = profile;
          _stores[profile.id] = profile;
          _businessProfile = profile;
        }
        _activeStoreId = prefs.getString('active_store_id') ?? (_businessProfile?.id ?? (_stores.isNotEmpty ? _stores.keys.first : ''));
        if (_activeStoreId.isNotEmpty && _stores.containsKey(_activeStoreId)) {
          _businessProfile = _stores[_activeStoreId];
        }
        await _loadCollections(prefs);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('DatabaseHelper init error: $e');
      _initialized = true;
    }
  }

  Future<void> _loadCollections(SharedPreferences prefs) async {
    // Products
    final productsStr = prefs.getString('db_products');
    if (productsStr != null) {
      final List list = jsonDecode(productsStr);
      for (var item in list) {
        final p = Product.fromMap(item);
        final sid = p.storeId.isNotEmpty ? p.storeId : _activeStoreId;
        _products[p.id] = p.copyWith(storeId: sid);
      }
    }

    // Categories
    final categoriesStr = prefs.getString('db_categories');
    if (categoriesStr != null) {
      final List list = jsonDecode(categoriesStr);
      for (var item in list) {
        final c = ProductCategory.fromMap(item);
        final sid = c.storeId.isNotEmpty ? c.storeId : _activeStoreId;
        _categories[c.id] = ProductCategory(
          id: c.id,
          storeId: sid,
          name: c.name,
          description: c.description,
          iconName: c.iconName,
          colorHex: c.colorHex,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
        );
      }
    } else {
      _seedCategoriesForStore(_activeStoreId, activeStoreType);
    }

    // Customers
    final customersStr = prefs.getString('db_customers');
    if (customersStr != null) {
      final List list = jsonDecode(customersStr);
      for (var item in list) {
        final c = Customer.fromMap(item);
        final sid = c.storeId.isNotEmpty ? c.storeId : _activeStoreId;
        _customers[c.id] = c.copyWith(storeId: sid);
      }
    }

    // Suppliers
    final suppliersStr = prefs.getString('db_suppliers');
    if (suppliersStr != null) {
      final List list = jsonDecode(suppliersStr);
      for (var item in list) {
        final s = Supplier.fromMap(item);
        final sid = s.storeId.isNotEmpty ? s.storeId : _activeStoreId;
        _suppliers[s.id] = s.copyWith(storeId: sid);
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
        final sid = s.storeId.isNotEmpty ? s.storeId : _activeStoreId;
        _sales[s.id] = s.copyWith(storeId: sid);
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
        final m = StockMovement.fromMap(item);
        final sid = m.storeId.isNotEmpty ? m.storeId : _activeStoreId;
        _stockMovements.add(StockMovement(
          id: m.id,
          storeId: sid,
          productId: m.productId,
          productName: m.productName,
          type: m.type,
          quantityDelta: m.quantityDelta,
          previousStock: m.previousStock,
          newStock: m.newStock,
          referenceId: m.referenceId,
          reason: m.reason,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
        ));
      }
    }

    // Invoices
    final invoicesStr = prefs.getString('db_invoices');
    if (invoicesStr != null) {
      final List list = jsonDecode(invoicesStr);
      for (var item in list) {
        final inv = Invoice.fromMap(item);
        final sid = inv.storeId.isNotEmpty ? inv.storeId : _activeStoreId;
        _invoices[inv.id] = Invoice(
          id: inv.id,
          storeId: sid,
          invoiceNumber: inv.invoiceNumber,
          saleId: inv.saleId,
          customerName: inv.customerName,
          customerMobile: inv.customerMobile,
          businessName: inv.businessName,
          businessGstin: inv.businessGstin,
          businessAddress: inv.businessAddress,
          businessMobile: inv.businessMobile,
          subtotal: inv.subtotal,
          discount: inv.discount,
          gst: inv.gst,
          total: inv.total,
          paymentMethod: inv.paymentMethod,
          format: inv.format,
          createdAt: inv.createdAt,
          updatedAt: inv.updatedAt,
        );
      }
    }

    // Sequence
    _invoiceSequence = prefs.getInt('db_invoice_sequence') ?? _sales.length;
  }

  void _seedCategoriesForStore(String storeId, String shopTypeId) {
    List<String> defaultNames;
    final type = shopTypeId.toLowerCase();

    if (type == 'electronics') {
      defaultNames = ['Audio & Headphones', 'Power & Chargers', 'Cables & Adapters', 'Accessories', 'Mobiles & Gadgets', 'Smart Devices'];
    } else if (type == 'clothing' || type == 'fashion') {
      defaultNames = ['Menswear', 'Womenswear', 'Dresses & Tops', 'Denim & Jeans', 'Ethnic Wear', 'Fashion Accessories'];
    } else if (type == 'medical' || type == 'pharmacy') {
      defaultNames = ['Medicines', 'Vitamins & Wellness', 'First Aid', 'Personal Hygiene', 'Health Devices', 'Skincare'];
    } else if (type == 'grocery') {
      defaultNames = ['Dairy & Milk', 'Staples & Grains', 'Edible Oils', 'Spices & Condiments', 'Beverages', 'Packaged Foods'];
    } else if (type == 'bakery') {
      defaultNames = ['Cakes & Pastries', 'Fresh Breads', 'Cookies & Biscuits', 'Beverages & Coffee', 'Confectionery', 'Savories'];
    } else if (type == 'retail') {
      defaultNames = ['General', 'Foodgrains & Staples', 'Edible Oils', 'Snacks & Biscuits', 'Soaps & Detergents', 'Daily Needs'];
    } else {
      defaultNames = ['General Items', 'Supplies', 'Wholesale Goods', 'Hardware & Tools', 'Custom Trade'];
    }

    for (var name in defaultNames) {
      final id = 'cat_${storeId}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      _categories[id] = ProductCategory(
        id: id,
        storeId: storeId,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // --- PERSISTENCE HELPERS ---
  String _userKey(String base) => _activeUserId.isNotEmpty ? '${base}_$_activeUserId' : base;

  // --- PERSISTENCE HELPERS ---
  Future<void> _persistStores() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _stores.values.map((s) => s.toMap()).toList();
    await prefs.setString(_userKey('db_stores'), jsonEncode(list));
    final allList = _allKnownStores.values.map((s) => s.toMap()).toList();
    await prefs.setString('db_stores', jsonEncode(allList));
    if (_activeUserId.isNotEmpty) {
      await syncToCloud();
    }
  }

  Future<void> _persistProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _products.values.map((p) => p.toMap()).toList();
    await prefs.setString(_userKey('db_products'), jsonEncode(list));
    if (_activeUserId.isNotEmpty) {
      await syncToCloud();
    }
  }

  Future<void> _persistCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _categories.values.map((c) => c.toMap()).toList();
    await prefs.setString(_userKey('db_categories'), jsonEncode(list));
    if (_activeUserId.isNotEmpty) {
      await syncToCloud();
    }
  }

  Future<void> _persistCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _customers.values.map((c) => c.toMap()).toList();
    await prefs.setString(_userKey('db_customers'), jsonEncode(list));
    if (_activeUserId.isNotEmpty) {
      await syncToCloud();
    }
  }

  Future<void> _persistSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _suppliers.values.map((s) => s.toMap()).toList();
    await prefs.setString(_userKey('db_suppliers'), jsonEncode(list));
    if (_activeUserId.isNotEmpty) {
      await syncToCloud();
    }
  }

  Future<void> _persistSalesAndStock() async {
    final prefs = await SharedPreferences.getInstance();
    final sList = _sales.values.map((s) => s.toMap()).toList();
    final siList = _saleItems.map((si) => si.toMap()).toList();
    final pList = _payments.map((p) => p.toMap()).toList();
    final smList = _stockMovements.map((sm) => sm.toMap()).toList();
    final invList = _invoices.values.map((inv) => inv.toMap()).toList();

    await prefs.setString(_userKey('db_sales'), jsonEncode(sList));
    await prefs.setString(_userKey('db_sale_items'), jsonEncode(siList));
    await prefs.setString(_userKey('db_payments'), jsonEncode(pList));
    await prefs.setString(_userKey('db_stock_movements'), jsonEncode(smList));
    await prefs.setString(_userKey('db_invoices'), jsonEncode(invList));
    await prefs.setInt(_userKey('db_invoice_sequence'), _invoiceSequence);
    await _persistProducts();
  }

  String _activeUserId = '';
  String get activeUserId => _activeUserId;

  Future<void> setActiveUserId(String uid) async {
    _activeUserId = uid;
    final prefs = await SharedPreferences.getInstance();

    if (uid.isEmpty) {
      _stores.clear();
      _products.clear();
      _categories.clear();
      _customers.clear();
      _suppliers.clear();
      _sales.clear();
      _saleItems.clear();
      _payments.clear();
      _stockMovements.clear();
      _invoices.clear();
      _businessProfile = null;
      _activeStoreId = '';
      return;
    }

    _stores.clear();
    _products.clear();
    _categories.clear();
    _customers.clear();
    _suppliers.clear();
    _sales.clear();
    _saleItems.clear();
    _payments.clear();
    _stockMovements.clear();
    _invoices.clear();
    _businessProfile = null;
    _activeStoreId = '';

    await _loadUserPartition(prefs, uid);

    if (_stores.isEmpty) {
      final cloudBackup = await CloudSyncService().restoreUserData(uid);
      if (cloudBackup != null) {
        await _applyUserDataSnapshot(cloudBackup, uid, prefs);
      }
    }

    if (_stores.isNotEmpty) {
      final savedStoreId = prefs.getString(_userKey('active_store_id')) ?? '';
      if (savedStoreId.isNotEmpty && _stores.containsKey(savedStoreId)) {
        _activeStoreId = savedStoreId;
        _businessProfile = _stores[savedStoreId];
      } else {
        _activeStoreId = _stores.keys.first;
        _businessProfile = _stores[_activeStoreId];
      }
    }
  }

  Future<void> syncToCloud() async {
    if (_activeUserId.isEmpty) return;

    final snapshot = {
      'uid': _activeUserId,
      'activeStoreId': _activeStoreId,
      'stores': _stores.values.map((s) => s.toMap()).toList(),
      'products': _products.values.map((p) => p.toMap()).toList(),
      'categories': _categories.values.map((c) => c.toMap()).toList(),
      'customers': _customers.values.map((c) => c.toMap()).toList(),
      'suppliers': _suppliers.values.map((s) => s.toMap()).toList(),
      'sales': _sales.values.map((s) => s.toMap()).toList(),
      'saleItems': _saleItems.map((si) => si.toMap()).toList(),
      'payments': _payments.map((p) => p.toMap()).toList(),
      'stockMovements': _stockMovements.map((sm) => sm.toMap()).toList(),
      'invoices': _invoices.values.map((inv) => inv.toMap()).toList(),
      'settings': _appSettings?.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await CloudSyncService().backupUserData(_activeUserId, snapshot);
  }

  Future<void> _loadUserPartition(SharedPreferences prefs, String uid) async {
    final storesStr = prefs.getString(_userKey('db_stores')) ?? prefs.getString('db_stores');
    if (storesStr != null && storesStr.isNotEmpty) {
      try {
        final List list = jsonDecode(storesStr);
        for (var item in list) {
          final profile = BusinessProfile.fromMap(item);
          _allKnownStores[profile.id] = profile;
          if (profile.userId.isEmpty || profile.userId == uid) {
            _stores[profile.id] = profile.copyWith(userId: uid);
          }
        }
      } catch (_) {}
    }

    final productsStr = prefs.getString(_userKey('db_products')) ?? (_stores.isNotEmpty ? prefs.getString('db_products') : null);
    if (productsStr != null) {
      try {
        final List list = jsonDecode(productsStr);
        for (var item in list) {
          final p = Product.fromMap(item);
          _products[p.id] = p;
        }
      } catch (_) {}
    }

    final categoriesStr = prefs.getString(_userKey('db_categories')) ?? (_stores.isNotEmpty ? prefs.getString('db_categories') : null);
    if (categoriesStr != null) {
      try {
        final List list = jsonDecode(categoriesStr);
        for (var item in list) {
          final c = ProductCategory.fromMap(item);
          _categories[c.id] = c;
        }
      } catch (_) {}
    }

    final customersStr = prefs.getString(_userKey('db_customers')) ?? (_stores.isNotEmpty ? prefs.getString('db_customers') : null);
    if (customersStr != null) {
      try {
        final List list = jsonDecode(customersStr);
        for (var item in list) {
          final c = Customer.fromMap(item);
          _customers[c.id] = c;
        }
      } catch (_) {}
    }

    final suppliersStr = prefs.getString(_userKey('db_suppliers')) ?? (_stores.isNotEmpty ? prefs.getString('db_suppliers') : null);
    if (suppliersStr != null) {
      try {
        final List list = jsonDecode(suppliersStr);
        for (var item in list) {
          final s = Supplier.fromMap(item);
          _suppliers[s.id] = s;
        }
      } catch (_) {}
    }

    final salesStr = prefs.getString(_userKey('db_sales')) ?? (_stores.isNotEmpty ? prefs.getString('db_sales') : null);
    final saleItemsStr = prefs.getString(_userKey('db_sale_items')) ?? (_stores.isNotEmpty ? prefs.getString('db_sale_items') : null);
    if (saleItemsStr != null) {
      try {
        final List list = jsonDecode(saleItemsStr);
        _saleItems.clear();
        for (var item in list) {
          _saleItems.add(SaleItem.fromMap(item));
        }
      } catch (_) {}
    }

    if (salesStr != null) {
      try {
        final List list = jsonDecode(salesStr);
        for (var item in list) {
          final sId = item['id'];
          final items = _saleItems.where((si) => si.saleId == sId).toList();
          final s = Sale.fromMap(item, items);
          _sales[s.id] = s;
        }
      } catch (_) {}
    }

    final paymentsStr = prefs.getString(_userKey('db_payments')) ?? (_stores.isNotEmpty ? prefs.getString('db_payments') : null);
    if (paymentsStr != null) {
      try {
        final List list = jsonDecode(paymentsStr);
        _payments.clear();
        for (var item in list) {
          _payments.add(Payment.fromMap(item));
        }
      } catch (_) {}
    }

    final movementsStr = prefs.getString(_userKey('db_stock_movements')) ?? (_stores.isNotEmpty ? prefs.getString('db_stock_movements') : null);
    if (movementsStr != null) {
      try {
        final List list = jsonDecode(movementsStr);
        _stockMovements.clear();
        for (var item in list) {
          _stockMovements.add(StockMovement.fromMap(item));
        }
      } catch (_) {}
    }

    final invoicesStr = prefs.getString(_userKey('db_invoices')) ?? (_stores.isNotEmpty ? prefs.getString('db_invoices') : null);
    if (invoicesStr != null) {
      try {
        final List list = jsonDecode(invoicesStr);
        for (var item in list) {
          final inv = Invoice.fromMap(item);
          _invoices[inv.id] = inv;
        }
      } catch (_) {}
    }
  }

  Future<void> _applyUserDataSnapshot(Map<String, dynamic> snapshot, String uid, SharedPreferences prefs) async {
    if (snapshot.containsKey('stores')) {
      final List list = snapshot['stores'] as List? ?? [];
      for (var item in list) {
        final profile = BusinessProfile.fromMap(item as Map<String, dynamic>);
        _stores[profile.id] = profile.copyWith(userId: uid);
      }
    }

    if (snapshot.containsKey('products')) {
      final List list = snapshot['products'] as List? ?? [];
      for (var item in list) {
        final p = Product.fromMap(item as Map<String, dynamic>);
        _products[p.id] = p;
      }
    }

    if (snapshot.containsKey('categories')) {
      final List list = snapshot['categories'] as List? ?? [];
      for (var item in list) {
        final c = ProductCategory.fromMap(item as Map<String, dynamic>);
        _categories[c.id] = c;
      }
    }

    if (snapshot.containsKey('customers')) {
      final List list = snapshot['customers'] as List? ?? [];
      for (var item in list) {
        final c = Customer.fromMap(item as Map<String, dynamic>);
        _customers[c.id] = c;
      }
    }

    if (snapshot.containsKey('suppliers')) {
      final List list = snapshot['suppliers'] as List? ?? [];
      for (var item in list) {
        final s = Supplier.fromMap(item as Map<String, dynamic>);
        _suppliers[s.id] = s;
      }
    }

    if (snapshot.containsKey('saleItems')) {
      final List list = snapshot['saleItems'] as List? ?? [];
      _saleItems.clear();
      for (var item in list) {
        _saleItems.add(SaleItem.fromMap(item as Map<String, dynamic>));
      }
    }

    if (snapshot.containsKey('sales')) {
      final List list = snapshot['sales'] as List? ?? [];
      for (var item in list) {
        final sId = item['id'];
        final items = _saleItems.where((si) => si.saleId == sId).toList();
        final s = Sale.fromMap(item as Map<String, dynamic>, items);
        _sales[s.id] = s;
      }
    }

    if (snapshot.containsKey('payments')) {
      final List list = snapshot['payments'] as List? ?? [];
      _payments.clear();
      for (var item in list) {
        _payments.add(Payment.fromMap(item as Map<String, dynamic>));
      }
    }

    if (snapshot.containsKey('stockMovements')) {
      final List list = snapshot['stockMovements'] as List? ?? [];
      _stockMovements.clear();
      for (var item in list) {
        _stockMovements.add(StockMovement.fromMap(item as Map<String, dynamic>));
      }
    }

    if (snapshot.containsKey('invoices')) {
      final List list = snapshot['invoices'] as List? ?? [];
      for (var item in list) {
        final inv = Invoice.fromMap(item as Map<String, dynamic>);
        _invoices[inv.id] = inv;
      }
    }

    if (snapshot.containsKey('settings') && snapshot['settings'] != null) {
      _appSettings = AppSettings.fromMap(snapshot['settings'] as Map<String, dynamic>);
    }

    await _persistStores();
    await _persistProducts();
    await _persistCategories();
    await _persistCustomers();
    await _persistSuppliers();
    await _persistSalesAndStock();
  }

  // --- STORE CONTEXT & PROFILE MANAGEMENT ---
  String get activeStoreId => _activeStoreId.isNotEmpty ? _activeStoreId : (_businessProfile?.id ?? 'store_retail');
  String get activeStoreType => _businessProfile?.shopTypeId ?? 'retail';
  String get activeStoreName => _businessProfile?.businessName ?? 'SCANZO Store';
  BusinessProfile? get businessProfile => _stores[activeStoreId] ?? _businessProfile;

  List<BusinessProfile> getAllStores({String? userId}) {
    final uid = userId ?? _activeUserId;
    var list = (uid.isNotEmpty && uid != _activeUserId)
        ? _allKnownStores.values.toList()
        : _stores.values.toList();
    if (uid.isNotEmpty) {
      list = list.where((s) => s.userId == uid).toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  BusinessProfile? getStoreById(String storeId) {
    final s = _stores[storeId] ?? _allKnownStores[storeId];
    if (s != null && _activeUserId.isNotEmpty && s.userId.isNotEmpty && s.userId != _activeUserId) {
      return null;
    }
    return s;
  }

  Future<void> setActiveStore(String storeId) async {
    if (_stores.containsKey(storeId)) {
      _activeStoreId = storeId;
      _businessProfile = _stores[storeId];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_store_id', storeId);
      await prefs.setString(AppConstants.keyActiveBusiness, jsonEncode(_businessProfile!.toMap()));

      // Ensure store has categories
      if (_categories.values.where((c) => c.storeId == storeId).isEmpty) {
        _seedCategoriesForStore(storeId, _businessProfile!.shopTypeId);
        await _persistCategories();
      }
    }
  }

  Future<void> saveBusinessProfile(BusinessProfile profile, {bool makeActive = true}) async {
    final effectiveUserId = profile.userId.isNotEmpty ? profile.userId : _activeUserId;
    final toSave = (profile.userId.isEmpty && effectiveUserId.isNotEmpty)
        ? profile.copyWith(userId: effectiveUserId)
        : profile;

    _stores[toSave.id] = toSave;
    _allKnownStores[toSave.id] = toSave;
    if (makeActive || _activeStoreId.isEmpty) {
      _activeStoreId = toSave.id;
      _businessProfile = toSave;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_store_id', _activeStoreId);
    await prefs.setString(AppConstants.keyActiveBusiness, jsonEncode((_businessProfile ?? toSave).toMap()));
    await prefs.setBool(AppConstants.keyBusinessSetupCompleted, true);
    await _persistStores();

    // Ensure category seed
    if (_categories.values.where((c) => c.storeId == toSave.id).isEmpty) {
      _seedCategoriesForStore(toSave.id, toSave.shopTypeId);
      await _persistCategories();
    }
  }

  Future<BusinessProfile> createOrGetStoreForShopType(String shopTypeId, {String? storeName}) async {
    // Check if store with this shop type already exists for current user
    final cleanType = shopTypeId.toLowerCase();
    for (var s in _stores.values) {
      final userMatches = _activeUserId.isEmpty ? true : s.userId == _activeUserId;
      if (s.shopTypeId.toLowerCase() == cleanType && userMatches) {
        await setActiveStore(s.id);
        return s;
      }
    }

    // Otherwise create a new store
    final shopType = ShopType.getById(cleanType);
    final newStoreId = 'store_${cleanType}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final name = storeName ?? 'SCANZO ${shopType.title}';

    final profile = BusinessProfile(
      id: newStoreId,
      userId: _activeUserId,
      businessName: name,
      ownerName: _businessProfile?.ownerName ?? 'Store Owner',
      mobile: _businessProfile?.mobile ?? '9876543210',
      email: _businessProfile?.email,
      address: _businessProfile?.address ?? 'Market Square',
      city: _businessProfile?.city ?? 'City',
      state: _businessProfile?.state ?? 'State',
      pincode: _businessProfile?.pincode ?? '560001',
      gstin: _businessProfile?.gstin,
      invoicePrefix: shopType.id.substring(0, 3).toUpperCase(),
      currency: '₹',
      shopTypeId: cleanType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveBusinessProfile(profile, makeActive: true);
    return profile;
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

  // --- PRODUCTS (FILTERED BY STORE ID) ---
  List<Product> getAllProducts({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    return _products.values
        .where((p) => p.storeId == sid || (p.storeId.isEmpty && sid == activeStoreId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Product? getProductById(String id, {String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final p = _products[id];
    if (p != null && (p.storeId == sid || (p.storeId.isEmpty && sid == activeStoreId))) {
      return p;
    }
    return null;
  }

  Product? getProductByBarcode(String barcode, {String? storeId}) {
    if (barcode.trim().isEmpty) return null;
    final sid = storeId ?? activeStoreId;
    final cleanBarcode = barcode.trim().toLowerCase();
    try {
      return _products.values.firstWhere(
        (p) =>
            (p.storeId == sid || (p.storeId.isEmpty && sid == activeStoreId)) &&
            p.barcode.trim().toLowerCase() == cleanBarcode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProduct(Product product) async {
    final sid = product.storeId.isNotEmpty ? product.storeId : activeStoreId;
    final updated = product.copyWith(storeId: sid);
    _products[updated.id] = updated;
    await _persistProducts();
  }

  Future<void> bulkInsertProducts(List<Product> newProducts, {String? storeId}) async {
    final sid = storeId ?? activeStoreId;
    for (var p in newProducts) {
      final targetSid = p.storeId.isNotEmpty ? p.storeId : sid;
      _products[p.id] = p.copyWith(storeId: targetSid);
    }
    await _persistProducts();
  }

  Future<void> deleteProduct(String id) async {
    _products.remove(id);
    await _persistProducts();
  }

  List<Product> getLowStockProducts({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    return _products.values
        .where((p) =>
            (p.storeId == sid || (p.storeId.isEmpty && sid == activeStoreId)) &&
            (p.isLowStock || p.isOutOfStock))
        .toList();
  }

  // --- CATEGORIES (FILTERED BY STORE ID) ---
  List<ProductCategory> getAllCategories({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final cats = _categories.values
        .where((c) => c.storeId == sid || (c.storeId.isEmpty && sid == activeStoreId))
        .toList();
    if (cats.isEmpty) {
      _seedCategoriesForStore(sid, activeStoreType);
      return _categories.values.where((c) => c.storeId == sid).toList();
    }
    return cats;
  }

  Future<void> saveCategory(ProductCategory category) async {
    final sid = category.storeId.isNotEmpty ? category.storeId : activeStoreId;
    final updated = ProductCategory(
      id: category.id,
      storeId: sid,
      name: category.name,
      description: category.description,
      iconName: category.iconName,
      colorHex: category.colorHex,
      createdAt: category.createdAt,
      updatedAt: DateTime.now(),
    );
    _categories[updated.id] = updated;
    await _persistCategories();
  }

  Future<void> deleteCategory(String id) async {
    _categories.remove(id);
    await _persistCategories();
  }

  // --- CUSTOMERS (FILTERED BY STORE ID) ---
  List<Customer> getAllCustomers({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    return _customers.values
        .where((c) => c.storeId == sid || (c.storeId.isEmpty && sid == activeStoreId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Customer? getCustomerById(String id, {String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final c = _customers[id];
    if (c != null && (c.storeId == sid || (c.storeId.isEmpty && sid == activeStoreId))) {
      return c;
    }
    return null;
  }

  Future<void> saveCustomer(Customer customer) async {
    final sid = customer.storeId.isNotEmpty ? customer.storeId : activeStoreId;
    final updated = customer.copyWith(storeId: sid);
    _customers[updated.id] = updated;
    await _persistCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    _customers.remove(id);
    await _persistCustomers();
  }

  // --- SUPPLIERS (FILTERED BY STORE ID) ---
  List<Supplier> getAllSuppliers({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    return _suppliers.values
        .where((s) => s.storeId == sid || (s.storeId.isEmpty && sid == activeStoreId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Supplier? getSupplierById(String id, {String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final s = _suppliers[id];
    if (s != null && (s.storeId == sid || (s.storeId.isEmpty && sid == activeStoreId))) {
      return s;
    }
    return null;
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final sid = supplier.storeId.isNotEmpty ? supplier.storeId : activeStoreId;
    final updated = supplier.copyWith(storeId: sid);
    _suppliers[updated.id] = updated;
    await _persistSuppliers();
  }

  Future<void> deleteSupplier(String id) async {
    _suppliers.remove(id);
    await _persistSuppliers();
  }

  // --- BILLING / TRANSACTIONAL CHECKOUT ---
  int getNextInvoiceSequence({String? storeId}) {
    return _invoiceSequence + 1;
  }

  String generateNextInvoiceNumber({String? storeId}) {
    final currentProfile = businessProfile;
    final prefix = currentProfile?.invoicePrefix ?? _appSettings?.invoicePrefix ?? AppConstants.defaultInvoicePrefix;
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
    String? storeId,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cannot process checkout with empty cart.');
    }

    final sid = storeId ?? activeStoreId;
    _invoiceSequence++;
    final currentProfile = _stores[sid] ?? businessProfile;
    final prefix = currentProfile?.invoicePrefix ?? _appSettings?.invoicePrefix ?? AppConstants.defaultInvoicePrefix;
    final invoiceNumber = IdGenerator.generateInvoiceNumber(prefix, _invoiceSequence);
    final saleId = IdGenerator.generateId('sale');
    final now = DateTime.now();

    // 1. Create Sale Items & Deduct Stock strictly for this store
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
      if (product != null && (product.storeId == sid || (product.storeId.isEmpty && sid == activeStoreId))) {
        if (product.currentStock < item.quantity) {
          throw Exception('Insufficient inventory for "${product.name}". Available: ${product.currentStock.toStringAsFixed(0)}, Requested: ${item.quantity.toStringAsFixed(0)}');
        }
        final prevStock = product.currentStock;
        final newStock = (prevStock - item.quantity).clamp(0.0, double.infinity);
        _products[product.id] = product.copyWith(currentStock: newStock);

        _stockMovements.add(StockMovement(
          id: IdGenerator.generateId('mov'),
          storeId: sid,
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

    // 2. Create Sale with storeId
    final sale = Sale(
      id: saleId,
      storeId: sid,
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

    // 4. Create Invoice with storeId
    final invoice = Invoice(
      id: IdGenerator.generateId('inv'),
      storeId: sid,
      invoiceNumber: invoiceNumber,
      saleId: sale.id,
      customerName: customerName,
      customerMobile: customerMobile,
      businessName: currentProfile?.businessName ?? 'SCANZO Store',
      businessGstin: currentProfile?.gstin,
      businessAddress: currentProfile?.address ?? '',
      businessMobile: currentProfile?.mobile ?? '',
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

  // --- SALES QUERIES (FILTERED BY STORE ID) ---
  List<Sale> getAllSales({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final list = _sales.values
        .where((s) => s.storeId == sid || (s.storeId.isEmpty && sid == activeStoreId))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Sale? getSaleById(String id, {String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final s = _sales[id];
    if (s != null && (s.storeId == sid || (s.storeId.isEmpty && sid == activeStoreId))) {
      return s;
    }
    return null;
  }

  Invoice? getInvoiceBySaleId(String saleId) {
    try {
      return _invoices.values.firstWhere((inv) => inv.saleId == saleId);
    } catch (_) {
      return null;
    }
  }

  // --- STOCK MOVEMENTS & ADJUSTMENTS (FILTERED BY STORE ID) ---
  List<StockMovement> getAllStockMovements({String? storeId}) {
    final sid = storeId ?? activeStoreId;
    final list = _stockMovements
        .where((m) => m.storeId == sid || (m.storeId.isEmpty && sid == activeStoreId))
        .toList();
    return List.from(list.reversed);
  }

  Future<void> recordStockAdjustment({
    required String productId,
    required double newStock,
    required String type,
    String? reason,
    String? storeId,
  }) async {
    final sid = storeId ?? activeStoreId;
    final product = _products[productId];
    if (product == null) return;

    final prev = product.currentStock;
    final delta = newStock - prev;
    final now = DateTime.now();

    _products[productId] = product.copyWith(currentStock: newStock);

    _stockMovements.add(StockMovement(
      id: IdGenerator.generateId('adj'),
      storeId: sid,
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
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'activeStoreId': activeStoreId,
      'stores': _stores.values.map((s) => s.toMap()).toList(),
      'business': businessProfile?.toMap(),
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

    _stores.clear();
    if (data['stores'] != null) {
      for (var item in data['stores']) {
        final s = BusinessProfile.fromMap(item);
        _stores[s.id] = s;
      }
    }

    if (data['business'] != null) {
      _businessProfile = BusinessProfile.fromMap(data['business']);
      _stores[_businessProfile!.id] = _businessProfile!;
    }

    _activeStoreId = data['activeStoreId'] ?? _businessProfile?.id ?? (_stores.isNotEmpty ? _stores.keys.first : 'store_retail');

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
    await _persistStores();
    await _persistProducts();
    await _persistCategories();
    await _persistCustomers();
    await _persistSuppliers();
    await _persistSalesAndStock();
    if (_businessProfile != null) {
      await saveBusinessProfile(_businessProfile!, makeActive: true);
    }
    if (_appSettings != null) {
      await saveAppSettings(_appSettings!);
    }
  }

  // Clear data on reset
  Future<void> clearAllBusinessData({String? storeId}) async {
    final sid = storeId;
    if (sid != null) {
      // Clear data only for specific store
      _products.removeWhere((_, p) => p.storeId == sid);
      _customers.removeWhere((_, c) => c.storeId == sid);
      _suppliers.removeWhere((_, s) => s.storeId == sid);
      _sales.removeWhere((_, s) => s.storeId == sid);
      _saleItems.removeWhere((si) => _sales.values.any((s) => s.id == si.saleId && s.storeId == sid));
      _stockMovements.removeWhere((m) => m.storeId == sid);
      _invoices.removeWhere((_, inv) => inv.storeId == sid);
      _categories.removeWhere((_, c) => c.storeId == sid);
      _seedCategoriesForStore(sid, _stores[sid]?.shopTypeId ?? 'retail');

      await _persistProducts();
      await _persistCustomers();
      await _persistSuppliers();
      await _persistCategories();
      await _persistSalesAndStock();
      return;
    }

    // Clear all
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

    _categories.clear();
    _seedCategoriesForStore(activeStoreId, activeStoreType);
    await _persistCategories();
  }
}
