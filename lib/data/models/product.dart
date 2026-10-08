class Product {
  final String id;
  final String storeId;
  final String sku;
  final String barcode;
  final String name;
  final String category;
  final String? subcategory;
  final String? brand;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double discount;
  final double gstRate;
  final double currentStock;
  final double minStock;
  final String? supplierId;
  final String? imagePath;
  final String? batch;
  final String? expiryDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    this.storeId = '',
    required this.sku,
    required this.barcode,
    required this.name,
    required this.category,
    this.subcategory,
    this.brand,
    this.unit = 'Pcs',
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    this.discount = 0.0,
    this.gstRate = 0.0,
    this.currentStock = 0.0,
    this.minStock = 5.0,
    this.supplierId,
    this.imagePath,
    this.batch,
    this.expiryDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minStock && currentStock > 0;
  bool get isOutOfStock => currentStock <= 0;
  double get profitMargin => sellingPrice - purchasePrice;
  double get stockValue => currentStock * purchasePrice;
  double get retailStockValue => currentStock * sellingPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'category': category,
      'subcategory': subcategory,
      'brand': brand,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'discount': discount,
      'gstRate': gstRate,
      'currentStock': currentStock,
      'minStock': minStock,
      'supplierId': supplierId,
      'imagePath': imagePath,
      'batch': batch,
      'expiryDate': expiryDate,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      sku: map['sku'] ?? '',
      barcode: map['barcode'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      subcategory: map['subcategory'],
      brand: map['brand'],
      unit: map['unit'] ?? 'Pcs',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['minStock'] as num?)?.toDouble() ?? 5.0,
      supplierId: map['supplierId'],
      imagePath: map['imagePath'],
      batch: map['batch'],
      expiryDate: map['expiryDate'],
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Product copyWith({
    String? id,
    String? storeId,
    String? sku,
    String? barcode,
    String? name,
    String? category,
    String? subcategory,
    String? brand,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? mrp,
    double? discount,
    double? gstRate,
    double? currentStock,
    double? minStock,
    String? supplierId,
    String? imagePath,
    String? batch,
    String? expiryDate,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      brand: brand ?? this.brand,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      discount: discount ?? this.discount,
      gstRate: gstRate ?? this.gstRate,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      supplierId: supplierId ?? this.supplierId,
      imagePath: imagePath ?? this.imagePath,
      batch: batch ?? this.batch,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
