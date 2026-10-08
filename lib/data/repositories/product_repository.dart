import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';

class ProductRepository {
  final DatabaseHelper _db;

  ProductRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  List<Product> getAllProducts({String? storeId}) => _db.getAllProducts(storeId: storeId);

  Product? getProductById(String id, {String? storeId}) => _db.getProductById(id, storeId: storeId);

  Product? getProductByBarcode(String barcode, {String? storeId}) => _db.getProductByBarcode(barcode, storeId: storeId);

  List<Product> getLowStockProducts({String? storeId}) => _db.getLowStockProducts(storeId: storeId);

  Future<void> saveProduct(Product product) => _db.saveProduct(product);

  Future<void> bulkInsertProducts(List<Product> products, {String? storeId}) => _db.bulkInsertProducts(products, storeId: storeId);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);

  List<ProductCategory> getAllCategories({String? storeId}) => _db.getAllCategories(storeId: storeId);

  Future<void> saveCategory(ProductCategory category) => _db.saveCategory(category);
}
