class Payment {
  final String id;
  final String saleId;
  final double amount;
  final String paymentMethod; // Cash, UPI, Card, Other
  final String? referenceNumber;
  final String status; // Completed, Pending, Failed
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.saleId,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.status = 'Completed',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'referenceNumber': referenceNumber,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] ?? '',
      saleId: map['saleId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      referenceNumber: map['referenceNumber'],
      status: map['status'] ?? 'Completed',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
