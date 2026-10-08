import 'sale_item.dart';

class Sale {
  final String id;
  final String storeId;
  final String invoiceNumber;
  final String? customerId;
  final String? customerName;
  final String? customerMobile;
  final double subtotal;
  final double totalDiscount;
  final double totalGst;
  final double grandTotal;
  final String paymentMethod;
  final String paymentStatus;
  final double paidAmount;
  final double changeAmount;
  final String? notes;
  final List<SaleItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sale({
    required this.id,
    this.storeId = '',
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.customerMobile,
    required this.subtotal,
    this.totalDiscount = 0.0,
    this.totalGst = 0.0,
    required this.grandTotal,
    required this.paymentMethod,
    this.paymentStatus = 'Paid',
    required this.paidAmount,
    this.changeAmount = 0.0,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'totalGst': totalGst,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, [List<SaleItem> items = const []]) {
    return Sale(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'],
      customerMobile: map['customerMobile'],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (map['totalDiscount'] as num?)?.toDouble() ?? 0.0,
      totalGst: (map['totalGst'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      paymentStatus: map['paymentStatus'] ?? 'Paid',
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (map['changeAmount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      items: items,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Sale copyWith({
    String? id,
    String? storeId,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? customerMobile,
    double? subtotal,
    double? totalDiscount,
    double? totalGst,
    double? grandTotal,
    String? paymentMethod,
    String? paymentStatus,
    double? paidAmount,
    double? changeAmount,
    String? notes,
    List<SaleItem>? items,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      subtotal: subtotal ?? this.subtotal,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      totalGst: totalGst ?? this.totalGst,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
