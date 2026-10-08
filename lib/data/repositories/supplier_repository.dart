import '../database/database_helper.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final DatabaseHelper _db;

  SupplierRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  List<Supplier> getAllSuppliers({String? storeId}) => _db.getAllSuppliers(storeId: storeId);

  Supplier? getSupplierById(String id, {String? storeId}) => _db.getSupplierById(id, storeId: storeId);

  Future<void> saveSupplier(Supplier supplier) => _db.saveSupplier(supplier);

  Future<void> deleteSupplier(String id) => _db.deleteSupplier(id);
}
