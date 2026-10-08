import '../database/database_helper.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final DatabaseHelper _db;

  SupplierRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  List<Supplier> getAllSuppliers() => _db.getAllSuppliers();

  Supplier? getSupplierById(String id) => _db.getSupplierById(id);

  Future<void> saveSupplier(Supplier supplier) => _db.saveSupplier(supplier);

  Future<void> deleteSupplier(String id) => _db.deleteSupplier(id);
}
