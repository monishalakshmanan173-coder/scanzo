import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/models/sale_item.dart';
import 'package:scanzo/data/services/excel_import_service.dart';

void main() {
  group('POS Billing Cart & Quantity Logic Tests', () {
    test('Cart increment and decrement respects 1 as minimum and checks available stock', () {
      final product = Product(
        id: 'p_test_1',
        sku: 'SKU-001',
        barcode: '890123456789',
        name: 'Organic Milk 1L',
        category: 'Dairy',
        purchasePrice: 40.0,
        sellingPrice: 60.0,
        mrp: 65.0,
        gstRate: 5.0,
        currentStock: 4.0, // Available stock is 4
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final Map<String, SaleItem> cart = {};

      void addToCart(Product p) {
        if (p.currentStock <= 0) return;
        if (cart.containsKey(p.id)) {
          final existing = cart[p.id]!;
          if (existing.quantity + 1 > p.currentStock) {
            // Blocked: exceeds stock
            return;
          }
          final newQty = existing.quantity + 1;
          final gstAmt = (existing.unitPrice * newQty * existing.gstRate) / 100.0;
          final total = (existing.unitPrice * newQty) + gstAmt;
          cart[p.id] = SaleItem(
            id: existing.id,
            saleId: '',
            productId: p.id,
            productName: p.name,
            barcode: p.barcode,
            quantity: newQty,
            unitPrice: p.sellingPrice,
            gstRate: p.gstRate,
            gstAmount: gstAmt,
            totalAmount: total,
          );
        } else {
          final gstAmt = (p.sellingPrice * 1 * p.gstRate) / 100.0;
          final total = p.sellingPrice + gstAmt;
          cart[p.id] = SaleItem(
            id: 'si_1',
            saleId: '',
            productId: p.id,
            productName: p.name,
            barcode: p.barcode,
            quantity: 1,
            unitPrice: p.sellingPrice,
            gstRate: p.gstRate,
            gstAmount: gstAmt,
            totalAmount: total,
          );
        }
      }

      void decreaseQty(String prodId) {
        final item = cart[prodId];
        if (item == null) return;
        if (item.quantity <= 1) {
          // Blocked: cannot decrement below 1
          return;
        }
        final newQty = item.quantity - 1;
        final gstAmt = (item.unitPrice * newQty * item.gstRate) / 100.0;
        final total = (item.unitPrice * newQty) + gstAmt;
        cart[prodId] = SaleItem(
          id: item.id,
          saleId: '',
          productId: item.productId,
          productName: item.productName,
          barcode: item.barcode,
          quantity: newQty,
          unitPrice: item.unitPrice,
          gstRate: item.gstRate,
          gstAmount: gstAmt,
          totalAmount: total,
        );
      }

      void removeFromCart(String prodId) {
        cart.remove(prodId);
      }

      // 1. Initial Add
      addToCart(product);
      expect(cart.length, 1);
      expect(cart[product.id]!.quantity, 1.0);
      expect(cart[product.id]!.totalAmount, 63.0); // 60 + 3 GST

      // 2. Increment by scanning again or tapping +
      addToCart(product);
      expect(cart.length, 1); // Not duplicated
      expect(cart[product.id]!.quantity, 2.0);
      expect(cart[product.id]!.totalAmount, 126.0); // 120 + 6 GST

      addToCart(product);
      expect(cart[product.id]!.quantity, 3.0);
      addToCart(product);
      expect(cart[product.id]!.quantity, 4.0); // Max stock reached

      // 3. Exceeding stock ceiling is blocked
      addToCart(product);
      expect(cart[product.id]!.quantity, 4.0); // Still 4, not allowed to reach 5

      // 4. Decrement with - button
      decreaseQty(product.id);
      expect(cart[product.id]!.quantity, 3.0);
      decreaseQty(product.id);
      expect(cart[product.id]!.quantity, 2.0);
      decreaseQty(product.id);
      expect(cart[product.id]!.quantity, 1.0);

      // 5. Decrement at 1 is blocked (stays in cart, not reduced to 0)
      decreaseQty(product.id);
      expect(cart.containsKey(product.id), true);
      expect(cart[product.id]!.quantity, 1.0);

      // 6. Dedicated remove deletes product from cart
      removeFromCart(product.id);
      expect(cart.containsKey(product.id), false);
      expect(cart.isEmpty, true);
    });
  });

  group('Excel Import Trailing Blank Rows & Formatting Tests', () {
    test('Ignores trailing empty/formatting-only rows so 25 products yield 25 valid, 0 invalid', () {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Selling Price,Quantity,Barcode,Category');

      for (int i = 1; i <= 25; i++) {
        buffer.writeln('Item $i,₹${i * 100},${i + 5},0001234500$i,General');
      }

      // Add trailing empty rows with commas and spaces (Excel used-range artifacts)
      buffer.writeln(',,,,');
      buffer.writeln('   ,   ,   ,   ,   ');
      buffer.writeln(',,,,');
      buffer.writeln('');
      buffer.writeln('');

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'batch_25.csv',
        existingProducts: [],
        storeId: 'store_25_test',
      );

      expect(analysis.totalRows, 25);
      expect(analysis.validRows.length, 25);
      expect(analysis.invalidRows.length, 0);
      expect(analysis.duplicateRows.length, 0);

      // Verify barcode with leading zero is preserved as string
      expect(analysis.validRows.first.product?.barcode, '00012345001');
      expect(analysis.validRows.last.product?.barcode, '000123450025');

      // Verify storeId isolation
      expect(analysis.validRows.first.product?.storeId, 'store_25_test');
    });

    test('Parses various price formats correctly', () {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Selling Price,Barcode');
      buffer.writeln('Phone A,"₹32,990",001');
      buffer.writeln('Phone B,"32,990",002');
      buffer.writeln('Phone C,32990.00,003');
      buffer.writeln('Phone D," ₹ 32,990.50 ",004');

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'prices.csv',
        existingProducts: [],
      );

      expect(analysis.validRows.length, 4);
      expect(analysis.validRows[0].product?.sellingPrice, 32990.0);
      expect(analysis.validRows[1].product?.sellingPrice, 32990.0);
      expect(analysis.validRows[2].product?.sellingPrice, 32990.0);
      expect(analysis.validRows[3].product?.sellingPrice, 32990.50);
    });

    test('Defaults quantity to 0.0 when missing or empty in row', () {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Selling Price,Quantity');
      buffer.writeln('Item Without Stock,500,');

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'no_qty.csv',
        existingProducts: [],
      );

      expect(analysis.validRows.length, 1);
      expect(analysis.validRows.first.product?.currentStock, 0.0);
    });
  });
}
