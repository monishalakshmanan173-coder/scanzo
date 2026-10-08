class BusinessProfile {
  final String id;
  final String userId;
  final String businessName;
  final String ownerName;
  final String mobile;
  final String? email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? gstin;
  final String? logoPath;
  final String invoicePrefix;
  final String currency;
  final bool isGstEnabled;
  final double defaultGstRate;
  final String shopTypeId;
  final String upiId;
  final String? upiQrData;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessProfile({
    required this.id,
    this.userId = '',
    required this.businessName,
    required this.ownerName,
    required this.mobile,
    this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.gstin,
    this.logoPath,
    this.invoicePrefix = 'SCZ',
    this.currency = '₹',
    this.isGstEnabled = true,
    this.defaultGstRate = 5.0,
    required this.shopTypeId,
    this.upiId = '',
    this.upiQrData,
    required this.createdAt,
    required this.updatedAt,
  });

  String get storeId => id;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'businessName': businessName,
      'ownerName': ownerName,
      'mobile': mobile,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gstin': gstin,
      'logoPath': logoPath,
      'invoicePrefix': invoicePrefix,
      'currency': currency,
      'isGstEnabled': isGstEnabled ? 1 : 0,
      'defaultGstRate': defaultGstRate,
      'shopTypeId': shopTypeId,
      'upiId': upiId,
      'upiQrData': upiQrData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      businessName: map['businessName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'],
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      gstin: map['gstin'],
      logoPath: map['logoPath'],
      invoicePrefix: map['invoicePrefix'] ?? 'SCZ',
      currency: map['currency'] ?? '₹',
      isGstEnabled: map['isGstEnabled'] == 1 || map['isGstEnabled'] == true,
      defaultGstRate: (map['defaultGstRate'] as num?)?.toDouble() ?? 5.0,
      shopTypeId: map['shopTypeId'] ?? 'retail',
      upiId: map['upiId'] ?? '',
      upiQrData: map['upiQrData'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  BusinessProfile copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? ownerName,
    String? mobile,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? logoPath,
    String? invoicePrefix,
    String? currency,
    bool? isGstEnabled,
    double? defaultGstRate,
    String? shopTypeId,
    String? upiId,
    String? upiQrData,
    DateTime? updatedAt,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstin: gstin ?? this.gstin,
      logoPath: logoPath ?? this.logoPath,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      currency: currency ?? this.currency,
      isGstEnabled: isGstEnabled ?? this.isGstEnabled,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      shopTypeId: shopTypeId ?? this.shopTypeId,
      upiId: upiId ?? this.upiId,
      upiQrData: upiQrData ?? this.upiQrData,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
