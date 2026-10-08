import '../database/database_helper.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final DatabaseHelper _db;

  SettingsRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  AppSettings getSettings() => _db.appSettings;

  Future<void> saveSettings(AppSettings settings) => _db.saveAppSettings(settings);

  String exportBackupJson() => _db.exportFullDatabaseJson();

  Future<void> importBackupJson(String json) => _db.importFullDatabaseJson(json);

  Future<void> resetAllData() => _db.clearAllBusinessData();
}
