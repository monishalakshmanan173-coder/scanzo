class AppSettings {
  final String id;
  final String invoicePrefix;
  final String defaultReceiptFormat; // Standard, 58mm, 80mm, A4
  final String invoiceFooterNote;
  final bool enableGst;
  final double defaultGstRate;
  final double defaultLowStockThreshold;
  final bool enableLowStockAlerts;
  final bool autoPrintReceipt;
  final bool soundEffectsEnabled;
  final String defaultPaymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    this.invoicePrefix = 'SCZ',
    this.defaultReceiptFormat = 'Standard Invoice',
    this.invoiceFooterNote = 'Thank you for shopping with us! Visit again.',
    this.enableGst = true,
    this.defaultGstRate = 5.0,
    this.defaultLowStockThreshold = 5.0,
    this.enableLowStockAlerts = true,
    this.autoPrintReceipt = false,
    this.soundEffectsEnabled = true,
    this.defaultPaymentMethod = 'Cash',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoicePrefix': invoicePrefix,
      'defaultReceiptFormat': defaultReceiptFormat,
      'invoiceFooterNote': invoiceFooterNote,
      'enableGst': enableGst ? 1 : 0,
      'defaultGstRate': defaultGstRate,
      'defaultLowStockThreshold': defaultLowStockThreshold,
      'enableLowStockAlerts': enableLowStockAlerts ? 1 : 0,
      'autoPrintReceipt': autoPrintReceipt ? 1 : 0,
      'soundEffectsEnabled': soundEffectsEnabled ? 1 : 0,
      'defaultPaymentMethod': defaultPaymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] ?? 'default_settings',
      invoicePrefix: map['invoicePrefix'] ?? 'SCZ',
      defaultReceiptFormat: map['defaultReceiptFormat'] ?? 'Standard Invoice',
      invoiceFooterNote: map['invoiceFooterNote'] ?? 'Thank you for shopping with us! Visit again.',
      enableGst: map['enableGst'] == 1 || map['enableGst'] == true,
      defaultGstRate: (map['defaultGstRate'] as num?)?.toDouble() ?? 5.0,
      defaultLowStockThreshold: (map['defaultLowStockThreshold'] as num?)?.toDouble() ?? 5.0,
      enableLowStockAlerts: map['enableLowStockAlerts'] == 1 || map['enableLowStockAlerts'] == true,
      autoPrintReceipt: map['autoPrintReceipt'] == 1 || map['autoPrintReceipt'] == true,
      soundEffectsEnabled: map['soundEffectsEnabled'] == 1 || map['soundEffectsEnabled'] == true,
      defaultPaymentMethod: map['defaultPaymentMethod'] ?? 'Cash',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AppSettings copyWith({
    String? id,
    String? invoicePrefix,
    String? defaultReceiptFormat,
    String? invoiceFooterNote,
    bool? enableGst,
    double? defaultGstRate,
    double? defaultLowStockThreshold,
    bool? enableLowStockAlerts,
    bool? autoPrintReceipt,
    bool? soundEffectsEnabled,
    String? defaultPaymentMethod,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      defaultReceiptFormat: defaultReceiptFormat ?? this.defaultReceiptFormat,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      enableGst: enableGst ?? this.enableGst,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      defaultLowStockThreshold: defaultLowStockThreshold ?? this.defaultLowStockThreshold,
      enableLowStockAlerts: enableLowStockAlerts ?? this.enableLowStockAlerts,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
