import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';

class ProductRepository {
  final DatabaseHelper _db;

  ProductRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  List<Product> getAllProducts() => _db.getAllProducts();

  Product? getProductById(String id) => _db.getProductById(id);

  Product? getProductByBarcode(String barcode) => _db.getProductByBarcode(barcode);

  List<Product> getLowStockProducts() => _db.getLowStockProducts();

  Future<void> saveProduct(Product product) => _db.saveProduct(product);

  Future<void> bulkInsertProducts(List<Product> products) => _db.bulkInsertProducts(products);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);

  List<ProductCategory> getAllCategories() => _db.getAllCategories();

  Future<void> saveCategory(ProductCategory category) => _db.saveCategory(category);
}
