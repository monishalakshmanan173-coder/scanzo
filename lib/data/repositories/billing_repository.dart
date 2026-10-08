import '../database/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/invoice.dart';

class BillingRepository {
  final DatabaseHelper _db;

  BillingRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String get activeStoreId => _db.activeStoreId;

  String getNextInvoiceNumber({String? storeId}) => _db.generateNextInvoiceNumber(storeId: storeId);

  List<Sale> getAllSales({String? storeId}) => _db.getAllSales(storeId: storeId);

  Sale? getSaleById(String id, {String? storeId}) => _db.getSaleById(id, storeId: storeId);

  Invoice? getInvoiceBySaleId(String saleId) => _db.getInvoiceBySaleId(saleId);

  Future<Sale> processCheckout({
    required String? customerId,
    required String? customerName,
    required String? customerMobile,
    required List<SaleItem> items,
    required double subtotal,
    required double totalDiscount,
    required double totalGst,
    required double grandTotal,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    String? notes,
    String? storeId,
  }) {
    return _db.processCheckout(
      customerId: customerId,
      customerName: customerName,
      customerMobile: customerMobile,
      items: items,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      totalGst: totalGst,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      notes: notes,
      storeId: storeId,
    );
  }
}
