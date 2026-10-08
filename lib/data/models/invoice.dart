class Invoice {
  final String id;
  final String storeId;
  final String invoiceNumber;
  final String saleId;
  final String? customerName;
  final String? customerMobile;
  final String businessName;
  final String? businessGstin;
  final String businessAddress;
  final String businessMobile;
  final double subtotal;
  final double discount;
  final double gst;
  final double total;
  final String paymentMethod;
  final String format; // Standard, 58mm, 80mm, A4
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    required this.id,
    this.storeId = '',
    required this.invoiceNumber,
    required this.saleId,
    this.customerName,
    this.customerMobile,
    required this.businessName,
    this.businessGstin,
    required this.businessAddress,
    required this.businessMobile,
    required this.subtotal,
    this.discount = 0.0,
    this.gst = 0.0,
    required this.total,
    required this.paymentMethod,
    this.format = 'Standard Invoice',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'invoiceNumber': invoiceNumber,
      'saleId': saleId,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'businessName': businessName,
      'businessGstin': businessGstin,
      'businessAddress': businessAddress,
      'businessMobile': businessMobile,
      'subtotal': subtotal,
      'discount': discount,
      'gst': gst,
      'total': total,
      'paymentMethod': paymentMethod,
      'format': format,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      saleId: map['saleId'] ?? '',
      customerName: map['customerName'],
      customerMobile: map['customerMobile'],
      businessName: map['businessName'] ?? '',
      businessGstin: map['businessGstin'],
      businessAddress: map['businessAddress'] ?? '',
      businessMobile: map['businessMobile'] ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      gst: (map['gst'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      format: map['format'] ?? 'Standard Invoice',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
