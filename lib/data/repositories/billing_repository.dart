import '../database/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/invoice.dart';

class BillingRepository {
  final DatabaseHelper _db;

  BillingRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  String getNextInvoiceNumber() => _db.generateNextInvoiceNumber();

  List<Sale> getAllSales() => _db.getAllSales();

  Sale? getSaleById(String id) => _db.getSaleById(id);

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
    );
  }
}
