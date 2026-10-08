class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String barcode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double purchasePrice;
  final double discountAmount;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    this.barcode = '',
    required this.quantity,
    this.unit = 'Pcs',
    required this.unitPrice,
    this.purchasePrice = 0.0,
    this.discountAmount = 0.0,
    this.gstRate = 0.0,
    this.gstAmount = 0.0,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'purchasePrice': purchasePrice,
      'discountAmount': discountAmount,
      'gstRate': gstRate,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] ?? '',
      saleId: map['saleId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      barcode: map['barcode'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'Pcs',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gstAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
