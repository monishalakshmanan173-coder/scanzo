import '../database/database_helper.dart';
import '../models/business_profile.dart';

class BusinessRepository {
  final DatabaseHelper _db;

  BusinessRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  BusinessProfile? getBusinessProfile() {
    return _db.businessProfile;
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    await _db.saveBusinessProfile(profile);
  }
}
