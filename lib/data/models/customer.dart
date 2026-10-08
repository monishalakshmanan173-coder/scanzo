class Customer {
  final String id;
  final String storeId;
  final String name;
  final String mobile;
  final String? email;
  final String? address;
  final double pendingBalance;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    this.storeId = '',
    required this.name,
    required this.mobile,
    this.email,
    this.address,
    this.pendingBalance = 0.0,
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
      'pendingBalance': pendingBalance,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'],
      address: map['address'],
      pendingBalance: (map['pendingBalance'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Customer copyWith({
    String? id,
    String? storeId,
    String? name,
    String? mobile,
    String? email,
    String? address,
    double? pendingBalance,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
