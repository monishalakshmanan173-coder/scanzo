import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class InventoryRepository {
  final DatabaseHelper _db;

  InventoryRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  List<Product> getAllProducts() => _db.getAllProducts();

  List<Product> getLowStockProducts() => _db.getLowStockProducts();

  List<StockMovement> getMovements() => _db.getAllStockMovements();

  double getTotalStockValuation() {
    double total = 0.0;
    for (var p in _db.getAllProducts()) {
      total += p.stockValue;
    }
    return total;
  }

  double getTotalRetailStockValuation() {
    double total = 0.0;
    for (var p in _db.getAllProducts()) {
      total += p.retailStockValue;
    }
    return total;
  }

  Future<void> recordAdjustment({
    required String productId,
    required double newStock,
    required String type,
    String? reason,
  }) {
    return _db.recordStockAdjustment(
      productId: productId,
      newStock: newStock,
      type: type,
      reason: reason,
    );
  }
}
