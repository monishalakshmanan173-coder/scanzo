import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/core/constants/app_constants.dart';
import 'package:scanzo/core/errors/app_exceptions.dart';
import 'package:scanzo/data/services/session_service.dart';
import 'package:scanzo/data/services/cloud_sync_service.dart';
import 'package:scanzo/data/repositories/auth_repository.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/sale_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository, Firebase UID & Permanent Persistence Tests', () {
    late SessionService sessionService;
    late CloudSyncService cloudSync;
    late AuthRepository authRepo;
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sessionService = SessionService();
      await sessionService.init();
      cloudSync = CloudSyncService();
      authRepo = AuthRepository(sessionService: sessionService, cloudSync: cloudSync);
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();
    });

    test('Send OTP validates 10-digit mobile number', () async {
      expect(
        () => authRepo.sendOtp('123', isNewAccount: true),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => authRepo.sendOtp('abcdefghij', isNewAccount: true),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(authRepo.sendOtp('9876543210', isNewAccount: true), completes);
    });

    test('Login for non-existent account allows OTP send and rejects on verify', () async {
      const mobile = '9111222333';
      // Any legitimate mobile number can start Firebase Phone Auth flow
      await expectLater(authRepo.sendOtp(mobile, isNewAccount: false), completes);

      // Verify OTP directly for Login must reject non-existent account
      expect(
        () => authRepo.verifyOtpAndLogin(
          mobile: mobile,
          otp: AppConstants.devTestOtp,
          isNewAccount: false,
        ),
        throwsA(predicate((e) =>
            e is AuthException && e.message.contains('Account not found. Please create an account first.'))),
      );
    });

    test('Create Account registers user permanently and enables subsequent Login', () async {
      const mobile = '9876543210';

      // 1. Send OTP for new account succeeds
      await expectLater(authRepo.sendOtp(mobile, isNewAccount: true), completes);

      // 2. Verify OTP and complete Create Account
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: AppConstants.devTestOtp,
        isNewAccount: true,
        ownerName: 'Ramesh Patel',
        businessName: 'Patel Electronics',
        businessType: 'electronics',
      );

      expect(session.mobile, mobile);
      expect(session.ownerName, 'Ramesh Patel');
      expect(session.businessName, 'Patel Electronics');
      expect(authRepo.isLoggedIn, true);
      expect(await cloudSync.isAccountRegistered(mobile), true);

      // 3. Duplicate Create Account with same number must be rejected on verify
      await expectLater(authRepo.sendOtp(mobile, isNewAccount: true), completes);
      expect(
        () => authRepo.verifyOtpAndLogin(
          mobile: mobile,
          otp: AppConstants.devTestOtp,
          isNewAccount: true,
        ),
        throwsA(predicate((e) =>
            e is AuthException && e.message.contains('An account already exists for this number'))),
      );

      // 4. Logout
      await authRepo.logout();
      expect(authRepo.isLoggedIn, false);

      // 5. Subsequent Login with existing number now succeeds
      await expectLater(authRepo.sendOtp(mobile, isNewAccount: false), completes);
      final loginSession = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: AppConstants.devTestOtp,
        isNewAccount: false,
      );
      expect(loginSession.mobile, mobile);
      expect(authRepo.isLoggedIn, true);
    });

    test('User Data Isolation: User A cannot see User B stores, products, or sales', () async {
      // Create User A
      const mobileA = '9000000001';
      final sessionA = await authRepo.verifyOtpAndLogin(
        mobile: mobileA,
        otp: AppConstants.devTestOtp,
        isNewAccount: true,
        ownerName: 'User Alpha',
        businessName: 'Alpha Store',
      );
      final uidA = sessionA.id;
      await db.setActiveUserId(uidA);

      // Add product for User A
      final prodA = Product(
        id: 'prod_a',
        storeId: db.activeStoreId,
        sku: 'SKU-A',
        barcode: '111111111111',
        name: 'Alpha Gadget',
        category: 'Electronics',
        purchasePrice: 100,
        sellingPrice: 150,
        mrp: 160,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(prodA);
      expect(db.getAllProducts().length, 1);
      expect(db.getAllProducts().first.name, 'Alpha Gadget');

      // Logout User A
      await authRepo.logout();

      // Create User B
      const mobileB = '9000000002';
      final sessionB = await authRepo.verifyOtpAndLogin(
        mobile: mobileB,
        otp: AppConstants.devTestOtp,
        isNewAccount: true,
        ownerName: 'User Beta',
        businessName: 'Beta Pharmacy',
      );
      final uidB = sessionB.id;
      await db.setActiveUserId(uidB);

      // Verify User B sees 0 products from User A!
      expect(db.getAllProducts().length, 0);

      // Add product for User B
      final prodB = Product(
        id: 'prod_b',
        storeId: db.activeStoreId,
        sku: 'SKU-B',
        barcode: '222222222222',
        name: 'Beta Medicine',
        category: 'Pharmacy',
        purchasePrice: 20,
        sellingPrice: 35,
        mrp: 40,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(prodB);
      expect(db.getAllProducts().length, 1);
      expect(db.getAllProducts().first.name, 'Beta Medicine');

      // Switch back to User A -> User A sees their product, not User B's!
      await db.setActiveUserId(uidA);
      final userAProducts = db.getAllProducts();
      expect(userAProducts.length, 1);
      expect(userAProducts.first.name, 'Alpha Gadget');
    });

    test('Reinstall Persistence Flow: Existing user restores stores, products and sales upon login', () async {
      const mobile = '9888877776';

      // 1. Create account & store setup
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: AppConstants.devTestOtp,
        isNewAccount: true,
        ownerName: 'Kavita Singh',
        businessName: 'Kavita Organics',
      );
      final uid = session.id;
      await db.setActiveUserId(uid);

      // 2. Add product
      final product = Product(
        id: 'prod_kavita_1',
        storeId: db.activeStoreId,
        sku: 'SKU-ORG-1',
        barcode: '8901122334455',
        name: 'Organic Green Honey 500g',
        category: 'Grocery',
        purchasePrice: 150,
        sellingPrice: 240,
        mrp: 260,
        currentStock: 25,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.saveProduct(product);

      // 3. Create a bill
      final item = SaleItem(
        id: 'si_test',
        saleId: '',
        productId: product.id,
        productName: product.name,
        quantity: 2,
        unitPrice: 240,
        totalAmount: 480,
      );
      await db.processCheckout(
        customerId: null,
        customerName: 'Customer Sunita',
        customerMobile: null,
        items: [item],
        subtotal: 480,
        totalDiscount: 0,
        totalGst: 0,
        grandTotal: 480,
        paymentMethod: 'Cash',
        paidAmount: 500,
        changeAmount: 20,
      );

      expect(db.getAllSales().length, 1);
      expect(db.getAllProducts().first.currentStock, 23); // 25 - 2

      // 4. User logs out
      await authRepo.logout();

      // 5. Simulate App Uninstall & Reinstall (clear in-memory and local database partitions)
      await db.setActiveUserId('');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('db_${uid}_stores');
      await prefs.remove('db_${uid}_products');
      await prefs.remove('db_${uid}_sales');

      // 6. User re-opens app and logs in with SAME phone number
      await expectLater(authRepo.sendOtp(mobile, isNewAccount: false), completes);
      await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: AppConstants.devTestOtp,
        isNewAccount: false,
      );

      // 7. Verify session and store data are restored from cloud backup!
      await db.setActiveUserId(uid);

      final restoredProducts = db.getAllProducts();
      final restoredSales = db.getAllSales();

      expect(restoredProducts.isNotEmpty, true);
      expect(restoredProducts.first.name, 'Organic Green Honey 500g');
      expect(restoredSales.length, 1);
      expect(restoredSales.first.customerName, 'Customer Sunita');
      expect(restoredSales.first.grandTotal, 480.0);
    });

    test('Verify OTP with invalid code throws human-friendly AuthException', () async {
      expect(
        () => authRepo.verifyOtpAndLogin(mobile: '9876543210', otp: '000000', isNewAccount: true),
        throwsA(predicate((e) => e is AuthException && e.message.contains('Invalid OTP'))),
      );
    });
  });
}
