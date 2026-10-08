import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class InventoryRepository {
  final DatabaseHelper _db;

  InventoryRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  List<Product> getAllProducts({String? storeId}) => _db.getAllProducts(storeId: storeId);

  List<Product> getLowStockProducts({String? storeId}) => _db.getLowStockProducts(storeId: storeId);

  List<StockMovement> getMovements({String? storeId}) => _db.getAllStockMovements(storeId: storeId);

  double getTotalStockValuation({String? storeId}) {
    double total = 0.0;
    for (var p in _db.getAllProducts(storeId: storeId)) {
      total += p.stockValue;
    }
    return total;
  }

  double getTotalRetailStockValuation({String? storeId}) {
    double total = 0.0;
    for (var p in _db.getAllProducts(storeId: storeId)) {
      total += p.retailStockValue;
    }
    return total;
  }

  Future<void> recordAdjustment({
    required String productId,
    required double newStock,
    required String type,
    String? reason,
    String? storeId,
  }) {
    return _db.recordStockAdjustment(
      productId: productId,
      newStock: newStock,
      type: type,
      reason: reason,
      storeId: storeId,
    );
  }
}
