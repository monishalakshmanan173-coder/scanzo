import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/services/excel_import_service.dart';

void main() {
  group('ExcelImportService Tests', () {
    test('generateSampleCsv outputs shop-specific CSV headers and template data for all shop types', () {
      final retailSample = ExcelImportService.generateSampleCsv('retail');
      expect(retailSample.contains('Product Code'), true);
      expect(retailSample.contains('Product Name'), true);
      expect(retailSample.contains('Selling Price'), true);

      final pharmaSample = ExcelImportService.generateSampleCsv('medical');
      expect(pharmaSample.contains('Paracetamol') || pharmaSample.contains('Medicines'), true);

      final elecSample = ExcelImportService.generateSampleCsv('electronics');
      expect(elecSample.contains('Headphone') || elecSample.contains('Charger') || elecSample.contains('Earbuds'), true);

      final fashionSample = ExcelImportService.generateSampleCsv('clothing');
      expect(fashionSample.contains('Shirt') || fashionSample.contains('Jeans') || fashionSample.contains('Menswear'), true);

      final grocerySample = ExcelImportService.generateSampleCsv('grocery');
      expect(grocerySample.contains('Rice') || grocerySample.contains('Atta') || grocerySample.contains('Grains'), true);

      final bakerySample = ExcelImportService.generateSampleCsv('bakery');
      expect(bakerySample.contains('Cake') || bakerySample.contains('Pastry') || bakerySample.contains('Bread'), true);
    });

    test('parseAndAnalyze detects valid products accurately', () {
      const csvData = '''
Product Code,Product Name,Category,Selling Price,Purchase Price,Opening Stock,Barcode
SKU-001,Almond Milk 1L,Dairy,75.00,55.00,20,8901234567890
SKU-002,Brown Bread 400g,Bakery,45.00,30.00,15,8901234567891
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'test.csv',
        existingProducts: [],
      );

      expect(analysis.totalRows, 2);
      expect(analysis.validRows.length, 2);
      expect(analysis.invalidRows.length, 0);
      expect(analysis.duplicateRows.length, 0);
      expect(analysis.validRows.first.product?.name, 'Almond Milk 1L');
      expect(analysis.validRows.first.product?.sellingPrice, 75.00);
      expect(analysis.validRows.first.product?.currentStock, 20.0);
    });

    test('parseAndAnalyze handles exactly 25 rows with currency signs, leading-zero barcodes, and ignores blank artifact rows', () {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Category,Selling Price,Purchase Cost,Quantity,Barcode,Brand');

      for (int i = 1; i <= 25; i++) {
        final barcode = '00${10000 + i}';
        final price = i == 1 ? '₹ 32,990' : '₹ ${i * 500}';
        final cost = '₹ ${i * 350}';
        buffer.writeln('Product #$i,Category Alpha,"$price","$cost",${10 + i},$barcode,Brand $i');
      }

      // Add empty lines and whitespace rows that previously caused 62 invalid rows bug
      buffer.writeln(',,,,,,');
      buffer.writeln('   ,   ,   ,   ,   ,   ,   ');
      buffer.writeln('');
      buffer.writeln('');

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: '25_products_import.csv',
        existingProducts: [],
        storeId: 'store_test_25',
      );

      // Verify exactly 25 rows detected and 25 valid products
      expect(analysis.totalRows, 25);
      expect(analysis.validRows.length, 25);
      expect(analysis.invalidRows.length, 0);
      expect(analysis.duplicateRows.length, 0);

      // Verify normalization of currency and retention of barcode leading zeros
      final first = analysis.validRows.first.product!;
      expect(first.name, 'Product #1');
      expect(first.sellingPrice, 32990.0);
      expect(first.purchasePrice, 350.0);
      expect(first.barcode, '0010001');
      expect(first.currentStock, 11.0);
      expect(first.storeId, 'store_test_25');

      final last = analysis.validRows.last.product!;
      expect(last.name, 'Product #25');
      expect(last.barcode, '0010025');
    });

    test('parseAndAnalyze binary .xlsx workbook with 25 product rows decoded via package:excel', () {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';

      // Header row
      excel.appendRow(sheetName, [
        TextCellValue('Item Name'),
        TextCellValue('Category'),
        TextCellValue('Retail Price'),
        TextCellValue('Cost Price'),
        TextCellValue('Stock Qty'),
        TextCellValue('Barcode Number'),
      ]);

      // 25 Product rows
      for (int i = 1; i <= 25; i++) {
        excel.appendRow(sheetName, [
          TextCellValue('Smart Tech Device #$i'),
          TextCellValue('Electronics'),
          TextCellValue('₹ 2,499.00'),
          TextCellValue('1600.00'),
          IntCellValue(20 + i),
          TextCellValue('008899$i'),
        ]);
      }

      final encodedBytes = Uint8List.fromList(excel.encode()!);
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: encodedBytes,
        fileName: 'catalog_batch.xlsx',
        existingProducts: [],
        storeId: 'store_elec_25',
      );

      // Must find exactly 25 rows, 0 invalid rows
      expect(analysis.totalRows, 25);
      expect(analysis.validRows.length, 25);
      expect(analysis.invalidRows.length, 0);
      expect(analysis.duplicateRows.length, 0);

      final product1 = analysis.validRows.first.product!;
      expect(product1.name, 'Smart Tech Device #1');
      expect(product1.sellingPrice, 2499.0);
      expect(product1.purchasePrice, 1600.0);
      expect(product1.currentStock, 21.0);
      expect(product1.barcode, '0088991');
      expect(product1.storeId, 'store_elec_25');
    });

    test('parseAndAnalyze detects invalid rows with missing name or invalid price', () {
      const csvData = '''
Product Code,Product Name,Category,Selling Price,Purchase Price,Opening Stock
SKU-001,,Dairy,75.00,55.00,20
SKU-002,Valid Item,Bakery,50.00,30.00,10
SKU-003,Broken Item,Snacks,,10.00,5
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'test.csv',
        existingProducts: [],
      );

      expect(analysis.totalRows, 3);
      expect(analysis.validRows.length, 1);
      expect(analysis.invalidRows.length, 2);
      expect(analysis.invalidRows.first.errors.contains('Missing Product Name'), true);
      expect(analysis.invalidRows.last.errors.contains('Missing Selling Price'), true);
    });

    test('parseAndAnalyze detects duplicates from existing database products', () {
      final existingProduct = Product(
        id: 'p1',
        sku: 'SKU-EXISTING',
        barcode: '8909999999999',
        name: 'Existing Soap',
        category: 'Personal Care',
        purchasePrice: 20,
        sellingPrice: 30,
        mrp: 35,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const csvData = '''
Product Code,Product Name,Category,Selling Price,Barcode
SKU-EXISTING,New Soap Copy,Personal Care,35.00,8909999999999
SKU-NEW,Unique Toothpaste,Personal Care,45.00,8908888888888
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final analysis = ExcelImportService.parseAndAnalyze(
        bytes: bytes,
        fileName: 'test.csv',
        existingProducts: [existingProduct],
      );

      expect(analysis.duplicateRows.length, 1);
      expect(analysis.validRows.length, 1);
      expect(analysis.duplicateRows.first.errors.any((e) => e.contains('Duplicate Barcode')), true);
    });
  });
}
