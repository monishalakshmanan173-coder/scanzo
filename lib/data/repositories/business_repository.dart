import '../database/database_helper.dart';
import '../models/business_profile.dart';

class BusinessRepository {
  final DatabaseHelper _db;

  BusinessRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  BusinessProfile? getBusinessProfile() {
    return _db.businessProfile;
  }

  String get activeStoreId => _db.activeStoreId;
  String get activeStoreType => _db.activeStoreType;
  String get activeStoreName => _db.activeStoreName;

  List<BusinessProfile> getAllStores() => _db.getAllStores();

  Future<void> setActiveStore(String storeId) => _db.setActiveStore(storeId);

  Future<BusinessProfile> createOrGetStoreForShopType(String shopTypeId, {String? storeName, String? customName}) =>
      _db.createOrGetStoreForShopType(shopTypeId, storeName: storeName ?? customName);

  String get activeStoreUpiId => _db.businessProfile?.upiId ?? '';

  Future<void> updateStoreUpiId(String upiId) async {
    final current = _db.businessProfile;
    if (current != null) {
      final updated = current.copyWith(upiId: upiId.trim());
      await _db.saveBusinessProfile(updated);
    }
  }

  Future<void> saveBusinessProfile(BusinessProfile profile, {bool makeActive = true}) async {
    await _db.saveBusinessProfile(profile, makeActive: makeActive);
  }
}
