import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/core/errors/app_exceptions.dart';
import 'package:scanzo/data/services/session_service.dart';
import 'package:scanzo/data/services/cloud_sync_service.dart';
import 'package:scanzo/data/services/otp_service.dart';
import 'package:scanzo/data/repositories/auth_repository.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/sale_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scanzo Authentication Flow Tests - All Cases & Security Requirements', () {
    late SessionService sessionService;
    late CloudSyncService cloudSync;
    late OtpService otpService;
    late AuthRepository authRepo;
    late DatabaseHelper db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sessionService = SessionService();
      await sessionService.logout();
      await sessionService.init();
      cloudSync = CloudSyncService();
      otpService = OtpService();
      otpService.clearSessionsForTesting();
      authRepo = AuthRepository(
        sessionService: sessionService,
        cloudSync: cloudSync,
        otpService: otpService,
      );
      db = DatabaseHelper();
      await db.init();
      await db.clearAllBusinessData();
    });

    test('Mobile validation: Send OTP validates 10-digit mobile number format', () async {
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

    test('CASE 1: New/unregistered phone number -> Login -> Account not found -> No OTP sent', () async {
      const unregisteredMobile = '9111222333';

      // 1. Check account exists must return false
      final exists = await authRepo.checkAccountExists(unregisteredMobile);
      expect(exists, false);

      // 2. Login sendOtp must throw 'Account not found. Please create an account first.'
      expect(
        () => authRepo.sendOtp(unregisteredMobile, isNewAccount: false),
        throwsA(predicate((e) =>
            e is AuthException && e.message == 'Account not found. Please create an account first.')),
      );

      // 3. Must remain logged out and no OTP dispatched
      expect(authRepo.isLoggedIn, false);
      expect(authRepo.currentUser, null);
    });

    test('CASE 2: Registered phone number -> Login -> OTP sent -> Correct OTP -> Dashboard', () async {
      const mobile = '9876543210';

      // 1. Register the account first
      await authRepo.preRegisterAccount(
        mobile: mobile,
        ownerName: 'Sunil Verma',
        businessName: 'Verma Supermarket',
      );
      final regVerId = await authRepo.sendOtp(mobile, isNewAccount: true);
      final regOtp = authRepo.otpService.getGeneratedOtpForTesting(regVerId)!;
      await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: regOtp,
        isNewAccount: true,
        ownerName: 'Sunil Verma',
        businessName: 'Verma Supermarket',
      );
      await authRepo.logout();
      expect(authRepo.isLoggedIn, false);

      // 2. Account exists check for login
      final exists = await authRepo.checkAccountExists(mobile);
      expect(exists, true);

      // 3. Send OTP for Login succeeds
      final loginVerId = await authRepo.sendOtp(mobile, isNewAccount: false);
      expect(loginVerId.isNotEmpty, true);

      // 4. Dynamic OTP is generated
      final dynamicOtp = authRepo.otpService.getGeneratedOtpForTesting(loginVerId);
      expect(dynamicOtp != null && dynamicOtp.length == 6, true);

      // 5. Verifying with correct OTP establishes session
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: dynamicOtp!,
        isNewAccount: false,
      );

      expect(authRepo.isLoggedIn, true);
      expect(session.mobile, mobile);
      expect(session.ownerName, 'Sunil Verma');
      expect(session.businessName, 'Verma Supermarket');
    });

    test('CASE 3: Create Account -> Account created -> OTP sent -> Correct OTP -> Dashboard', () async {
      const mobile = '9988776655';

      // 1. Account does not exist yet
      expect(await authRepo.checkAccountExists(mobile), false);

      // 2. Pre-register account details
      await authRepo.preRegisterAccount(
        mobile: mobile,
        ownerName: 'Priya Sharma',
        businessName: 'Priya Boutique',
        email: 'priya@boutique.com',
        businessType: 'apparel',
      );

      // 3. Send OTP for new account
      final verId = await authRepo.sendOtp(mobile, isNewAccount: true);
      expect(verId.isNotEmpty, true);

      final dynamicOtp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;
      expect(dynamicOtp.length, 6);

      // 4. Complete verification
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: dynamicOtp,
        isNewAccount: true,
        ownerName: 'Priya Sharma',
        businessName: 'Priya Boutique',
        email: 'priya@boutique.com',
        businessType: 'apparel',
      );

      expect(authRepo.isLoggedIn, true);
      expect(session.mobile, mobile);
      expect(session.ownerName, 'Priya Sharma');
      expect(session.businessName, 'Priya Boutique');
      expect(await authRepo.checkAccountExists(mobile), true);

      // 5. Subsequent attempt to create account with same number must fail
      expect(
        () => authRepo.sendOtp(mobile, isNewAccount: true),
        throwsA(predicate((e) =>
            e is AuthException && e.message.contains('An account already exists for this number'))),
      );
    });

    test('CASE 4: Wrong OTP -> Show invalid OTP error -> Do not login', () async {
      const mobile = '9555444333';

      final verId = await authRepo.sendOtp(mobile, isNewAccount: true);
      final realOtp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;

      // Provide a deliberately wrong OTP code
      final wrongOtp = realOtp == '111111' ? '222222' : '111111';

      expect(
        () => authRepo.verifyOtpAndLogin(
          mobile: mobile,
          otp: wrongOtp,
          isNewAccount: true,
        ),
        throwsA(predicate((e) =>
            e is AuthException && e.message == 'Invalid OTP. Please check the code and try again.')),
      );

      // User remains logged out
      expect(authRepo.isLoggedIn, false);
    });

    test('CASE 5: Expired OTP -> Show expired OTP error -> Allow resend', () async {
      const mobile = '9444333222';

      final verId = await authRepo.sendOtp(mobile, isNewAccount: true);
      final otp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;

      // Simulate expiration (beyond 5 minutes)
      authRepo.otpService.expireSessionForTesting(verId);

      expect(
        () => authRepo.verifyOtpAndLogin(
          mobile: mobile,
          otp: otp,
          isNewAccount: true,
        ),
        throwsA(predicate((e) =>
            e is AuthException && e.message == 'OTP expired. Please request a new OTP.')),
      );

      expect(authRepo.isLoggedIn, false);
    });

    test('CASE 6: Resend OTP -> Cooldown works -> New OTP is generated and sent', () async {
      const mobile = '9333222111';

      // 1. Initial send
      final verId1 = await authRepo.sendOtp(mobile, isNewAccount: true);
      final otp1 = authRepo.otpService.getGeneratedOtpForTesting(verId1)!;

      // 2. Rapid repeated request within 30-second cooldown must throw rate limit
      await expectLater(
        authRepo.sendOtp(mobile, isNewAccount: true),
        throwsA(predicate((e) =>
            e is AuthException && e.message == 'Too many attempts. Please wait and try again.')),
      );

      // 3. Clear cooldown and trigger Resend (with forceResend)
      otpService.clearSessionsForTesting();
      final verId2 = await authRepo.sendOtp(mobile, isNewAccount: true, forceResend: true);
      final otp2 = authRepo.otpService.getGeneratedOtpForTesting(verId2)!;

      expect(verId2.isNotEmpty, true);
      // New verification token issued
      expect(verId2 != verId1, true);

      // 4. Old OTP must fail
      if (otp1 != otp2) {
        expect(
          () => authRepo.verifyOtpAndLogin(
            mobile: mobile,
            otp: otp1,
            isNewAccount: true,
          ),
          throwsA(isA<AuthException>()),
        );
      }

      // 5. New OTP succeeds
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: otp2,
        isNewAccount: true,
      );
      expect(authRepo.isLoggedIn, true);
      expect(session.mobile, mobile);
    });

    test('OTP Security: Static/Fake OTPs (e.g. 123456, 999999) are rejected if not matching dynamic code', () async {
      const mobile = '9222111000';

      final verId = await authRepo.sendOtp(mobile, isNewAccount: true);
      final dynamicOtp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;

      // If dynamic OTP is not '123456', attempting '123456' must be rejected
      if (dynamicOtp != '123456') {
        expect(
          () => authRepo.verifyOtpAndLogin(
            mobile: mobile,
            otp: '123456',
            isNewAccount: true,
          ),
          throwsA(predicate((e) =>
              e is AuthException && e.message == 'Invalid OTP. Please check the code and try again.')),
        );
      }

      // Only the real dynamic OTP succeeds
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: dynamicOtp,
        isNewAccount: true,
      );
      expect(session.mobile, mobile);
      expect(authRepo.isLoggedIn, true);
    });

    test('User Data Isolation: User A cannot see User B stores, products, or sales', () async {
      // Create User A
      const mobileA = '9000000001';
      final verIdA = await authRepo.sendOtp(mobileA, isNewAccount: true);
      final otpA = authRepo.otpService.getGeneratedOtpForTesting(verIdA)!;
      final sessionA = await authRepo.verifyOtpAndLogin(
        mobile: mobileA,
        otp: otpA,
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
      final verIdB = await authRepo.sendOtp(mobileB, isNewAccount: true);
      final otpB = authRepo.otpService.getGeneratedOtpForTesting(verIdB)!;
      final sessionB = await authRepo.verifyOtpAndLogin(
        mobile: mobileB,
        otp: otpB,
        isNewAccount: true,
        ownerName: 'User Beta',
        businessName: 'Beta Pharmacy',
      );
      final uidB = sessionB.id;
      await db.setActiveUserId(uidB);

      // Verify User B sees 0 products from User A
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

      // Switch back to User A -> User A sees their product, not User B's
      await db.setActiveUserId(uidA);
      final userAProducts = db.getAllProducts();
      expect(userAProducts.length, 1);
      expect(userAProducts.first.name, 'Alpha Gadget');
    });

    test('Reinstall Persistence Flow: Existing user restores stores, products and sales upon login', () async {
      const mobile = '9888877776';

      // 1. Create account & store setup
      final verId = await authRepo.sendOtp(mobile, isNewAccount: true);
      final otp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;
      final session = await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: otp,
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

      // 5. Simulate App Uninstall & Reinstall
      await db.setActiveUserId('');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('db_${uid}_stores');
      await prefs.remove('db_${uid}_products');
      await prefs.remove('db_${uid}_sales');

      // 6. User logs in with SAME phone number
      expect(await authRepo.checkAccountExists(mobile), true);
      final loginVerId = await authRepo.sendOtp(mobile, isNewAccount: false);
      final loginOtp = authRepo.otpService.getGeneratedOtpForTesting(loginVerId)!;

      await authRepo.verifyOtpAndLogin(
        mobile: mobile,
        otp: loginOtp,
        isNewAccount: false,
      );

      // 7. Verify session and store data are restored
      await db.setActiveUserId(uid);
      final restoredProducts = db.getAllProducts();
      final restoredSales = db.getAllSales();

      expect(restoredProducts.isNotEmpty, true);
      expect(restoredProducts.first.name, 'Organic Green Honey 500g');
      expect(restoredSales.length, 1);
      expect(restoredSales.first.customerName, 'Customer Sunita');
      expect(restoredSales.first.grandTotal, 480.0);
    });
  });
}
