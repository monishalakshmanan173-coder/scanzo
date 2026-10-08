import '../database/database_helper.dart';
import '../models/customer.dart';

class CustomerRepository {
  final DatabaseHelper _db;

  CustomerRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  List<Customer> getAllCustomers({String? storeId}) => _db.getAllCustomers(storeId: storeId);

  Customer? getCustomerById(String id, {String? storeId}) => _db.getCustomerById(id, storeId: storeId);

  Future<void> saveCustomer(Customer customer) => _db.saveCustomer(customer);

  Future<void> deleteCustomer(String id) => _db.deleteCustomer(id);
}
