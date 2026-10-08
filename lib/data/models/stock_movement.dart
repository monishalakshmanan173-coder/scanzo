class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final String type; // PURCHASE, SALE, ADJUSTMENT, DAMAGED, RETURN
  final double quantityDelta; // can be positive or negative
  final double previousStock;
  final double newStock;
  final String? referenceId; // saleId, purchaseOrderId, etc.
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantityDelta,
    required this.previousStock,
    required this.newStock,
    this.referenceId,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'type': type,
      'quantityDelta': quantityDelta,
      'previousStock': previousStock,
      'newStock': newStock,
      'referenceId': referenceId,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      type: map['type'] ?? 'ADJUSTMENT',
      quantityDelta: (map['quantityDelta'] as num?)?.toDouble() ?? 0.0,
      previousStock: (map['previousStock'] as num?)?.toDouble() ?? 0.0,
      newStock: (map['newStock'] as num?)?.toDouble() ?? 0.0,
      referenceId: map['referenceId'],
      reason: map['reason'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
