class UserSession {
  final String id;
  final String ownerName;
  final String businessName;
  final String mobile;
  final String? email;
  final String? businessId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSession({
    required this.id,
    required this.ownerName,
    required this.businessName,
    required this.mobile,
    this.email,
    this.businessId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerName': ownerName,
      'businessName': businessName,
      'mobile': mobile,
      'email': email,
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      id: map['id'] ?? '',
      ownerName: map['ownerName'] ?? '',
      businessName: map['businessName'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'],
      businessId: map['businessId'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
