class AppConstants {
  // Brand
  static const String appName = 'SCANZO';
  static const String appTagline = 'Smart Billing & Business Management';
  static const String appVersion = '1.0.0';

  // Currency
  static const String defaultCurrencySymbol = '₹';
  static const String defaultCurrencyCode = 'INR';

  // Invoice
  static const String defaultInvoicePrefix = 'SCZ';

  // Standard Product Units
  static const List<String> productUnits = [
    'Pcs',
    'Kg',
    'Gram',
    'Litre',
    'Ml',
    'Box',
    'Pack',
    'Dozen',
    'Meter',
  ];

  // GST Rates in India
  static const List<double> standardGstRates = [
    0.0,
    5.0,
    12.0,
    18.0,
    28.0,
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'UPI',
    'Card',
    'Other',
  ];

  // Receipt Types
  static const List<String> receiptFormats = [
    'Standard Invoice',
    '58mm Thermal Receipt',
    '80mm Thermal Receipt',
    'A4 Full Invoice',
  ];

  // Stock Movement Types
  static const String stockMovementPurchase = 'PURCHASE';
  static const String stockMovementSale = 'SALE';
  static const String stockMovementAdjustment = 'ADJUSTMENT';
  static const String stockMovementDamaged = 'DAMAGED';
  static const String stockMovementReturn = 'RETURN';

  // Session keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserSession = 'user_session';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyBusinessSetupCompleted = 'business_setup_completed';
  static const String keyActiveBusiness = 'active_business';
  static const String keyAppSettings = 'app_settings';

  // Dev Test OTP (for dev mode verification only)
  static const String devTestOtp = '123456';
}
