import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/create_account_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/business/screens/shop_type_screen.dart';
import '../features/business/screens/business_details_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/products/screens/product_list_screen.dart';
import '../features/products/screens/add_edit_product_screen.dart';
import '../features/products/screens/excel_import_screen.dart';
import '../features/products/screens/barcode_scanner_screen.dart';
import '../features/billing/screens/pos_billing_screen.dart';
import '../features/billing/screens/bill_success_screen.dart';
import '../features/billing/screens/receipt_preview_screen.dart';
import '../features/billing/screens/sales_history_screen.dart';
import '../features/inventory/screens/inventory_screen.dart';
import '../features/customers/screens/customer_list_screen.dart';
import '../features/suppliers/screens/supplier_list_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/backup_restore_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String createAccount = '/create-account';
  static const String otp = '/otp';
  static const String onboarding = '/onboarding';
  static const String shopType = '/shop-type';
  static const String businessDetails = '/business-details';
  static const String dashboard = '/dashboard';
  static const String productList = '/products';
  static const String addEditProduct = '/products/add-edit';
  static const String excelImport = '/products/excel-import';
  static const String barcodeScanner = '/products/barcode-scanner';
  static const String posBilling = '/billing/pos';
  static const String billSuccess = '/billing/success';
  static const String receiptPreview = '/billing/receipt';
  static const String salesHistory = '/billing/sales-history';
  static const String inventory = '/inventory';
  static const String customerList = '/customers';
  static const String supplierList = '/suppliers';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String backupRestore = '/settings/backup-restore';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case createAccount:
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());
      case otp:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => OtpScreen(arguments: args));
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case shopType:
        return MaterialPageRoute(builder: (_) => const ShopTypeScreen());
      case businessDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) => BusinessDetailsScreen(arguments: args));
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case productList:
        return MaterialPageRoute(builder: (_) => const ProductListScreen());
      case addEditProduct:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) => AddEditProductScreen(arguments: args));
      case excelImport:
        return MaterialPageRoute(builder: (_) => const ExcelImportScreen());
      case barcodeScanner:
        return MaterialPageRoute(builder: (_) => const BarcodeScannerScreen());
      case posBilling:
        return MaterialPageRoute(builder: (_) => const PosBillingScreen());
      case billSuccess:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => BillSuccessScreen(arguments: args));
      case receiptPreview:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(arguments: args));
      case salesHistory:
        return MaterialPageRoute(builder: (_) => const SalesHistoryScreen());
      case inventory:
        return MaterialPageRoute(builder: (_) => const InventoryScreen());
      case customerList:
        return MaterialPageRoute(builder: (_) => const CustomerListScreen());
      case supplierList:
        return MaterialPageRoute(builder: (_) => const SupplierListScreen());
      case reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
      case settingsScreen:
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case backupRestore:
        return MaterialPageRoute(builder: (_) => const BackupRestoreScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }

  static const String settingsScreen = '/settings-screen';
}
