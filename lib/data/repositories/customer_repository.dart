import '../database/database_helper.dart';
import '../models/customer.dart';

class CustomerRepository {
  final DatabaseHelper _db;

  CustomerRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  List<Customer> getAllCustomers() => _db.getAllCustomers();

  Customer? getCustomerById(String id) => _db.getCustomerById(id);

  Future<void> saveCustomer(Customer customer) => _db.saveCustomer(customer);

  Future<void> deleteCustomer(String id) => _db.deleteCustomer(id);
}
