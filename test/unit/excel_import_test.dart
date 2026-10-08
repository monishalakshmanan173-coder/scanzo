import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanzo/data/models/product.dart';
import 'package:scanzo/data/services/excel_import_service.dart';

void main() {
  group('ExcelImportService Tests', () {
    test('generateSampleCsv outputs well-formed CSV headers and rows', () {
      final sample = ExcelImportService.generateSampleCsv();
      expect(sample.contains('Product Code'), true);
      expect(sample.contains('Product Name'), true);
      expect(sample.contains('Selling Price'), true);
      expect(sample.contains('Opening Stock'), true);
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
