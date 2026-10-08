class Supplier {
  final String id;
  final String storeId;
  final String name;
  final String mobile;
  final String? email;
  final String? address;
  final String? gstin;
  final double outstandingAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    this.storeId = '',
    required this.name,
    required this.mobile,
    this.email,
    this.address,
    this.gstin,
    this.outstandingAmount = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'mobile': mobile,
      'email': email,
      'address': address,
      'gstin': gstin,
      'outstandingAmount': outstandingAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'],
      address: map['address'],
      gstin: map['gstin'],
      outstandingAmount: (map['outstandingAmount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Supplier copyWith({
    String? id,
    String? storeId,
    String? name,
    String? mobile,
    String? email,
    String? address,
    String? gstin,
    double? outstandingAmount,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
