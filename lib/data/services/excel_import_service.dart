import 'dart:convert';
import 'dart:typed_data';
import '../models/product.dart';
import '../../core/utils/id_generator.dart';

class ImportRowResult {
  final int rowIndex;
  final Map<String, dynamic> rawData;
  final Product? product;
  final bool isValid;
  final bool isDuplicate;
  final List<String> errors;

  ImportRowResult({
    required this.rowIndex,
    required this.rawData,
    this.product,
    required this.isValid,
    this.isDuplicate = false,
    this.errors = const [],
  });
}

class ImportAnalysis {
  final int totalRows;
  final List<ImportRowResult> validRows;
  final List<ImportRowResult> invalidRows;
  final List<ImportRowResult> duplicateRows;
  final List<String> detectedHeaders;
  final List<String> missingRequiredHeaders;

  ImportAnalysis({
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.detectedHeaders,
    required this.missingRequiredHeaders,
  });

  bool get canProceed => validRows.isNotEmpty;
}

class ExcelImportService {
  static const List<String> requiredFields = ['Product Name', 'Selling Price'];

  static String generateSampleCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
        'Product Code,Product Name,Category,Subcategory,Brand,Barcode,Unit,Purchase Price,Selling Price,MRP,Discount,GST %,Opening Stock,Minimum Stock,Supplier,Batch,Expiry Date,Notes');
    buffer.writeln(
        'SKU-1001,Organic Wheat Flour,Groceries,Atta,Aashirvaad,8901030383123,Kg,45.00,55.00,60.00,0,5,50,10,,BATCH01,2027-12-31,Fresh stock');
    buffer.writeln(
        'SKU-1002,Tata Salt Pure,Groceries,Salt,Tata,8901030383456,Kg,22.00,28.00,30.00,0,0,100,20,,BATCH02,,Vacuum packed');
    buffer.writeln(
        'SKU-1003,Dairy Fresh Milk 500ml,Dairy,Milk,Amul,8901030383789,Pcs,28.00,34.00,34.00,0,0,30,5,,B99,2026-10-10,Store in fridge');
    return buffer.toString();
  }

  static ImportAnalysis parseAndAnalyze({
    required Uint8List bytes,
    required String fileName,
    required List<Product> existingProducts,
  }) {
    List<List<dynamic>> rows = [];

    // Check file type
    if (fileName.toLowerCase().endsWith('.csv')) {
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        rows.add(_parseCsvLine(line));
      }
    } else {
      // For XLSX or other formats, we parse through line/text extraction or table rows
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        rows.add(_parseCsvLine(line));
      }
    }

    if (rows.isEmpty) {
      return ImportAnalysis(
        totalRows: 0,
        validRows: [],
        invalidRows: [],
        duplicateRows: [],
        detectedHeaders: [],
        missingRequiredHeaders: requiredFields,
      );
    }

    // Process Headers
    final headerRow = rows.first;
    final headers = headerRow.map((e) => e.toString().trim()).toList();
    final headerIndexMap = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final normalized = _normalizeHeader(headers[i]);
      headerIndexMap[normalized] = i;
    }

    // Check required columns
    final missingReqs = <String>[];
    if (!headerIndexMap.containsKey('productname') && !headerIndexMap.containsKey('name')) {
      missingReqs.add('Product Name');
    }
    if (!headerIndexMap.containsKey('sellingprice') && !headerIndexMap.containsKey('price')) {
      missingReqs.add('Selling Price');
    }

    final validList = <ImportRowResult>[];
    final invalidList = <ImportRowResult>[];
    final duplicateList = <ImportRowResult>[];

    final existingBarcodes = existingProducts.map((p) => p.barcode.trim().toLowerCase()).toSet();
    final existingSkus = existingProducts.map((p) => p.sku.trim().toLowerCase()).toSet();

    final seenInFileBarcodes = <String>{};
    final seenInFileSkus = <String>{};

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

      final errors = <String>[];
      final rawData = <String, dynamic>{};

      for (int h = 0; h < headers.length && h < row.length; h++) {
        rawData[headers[h]] = row[h];
      }

      String getString(List<String> keys, [String defaultVal = '']) {
        for (var k in keys) {
          if (headerIndexMap.containsKey(k)) {
            final idx = headerIndexMap[k]!;
            if (idx < row.length) {
              final val = row[idx]?.toString().trim();
              if (val != null && val.isNotEmpty) return val;
            }
          }
        }
        return defaultVal;
      }

      double getDouble(List<String> keys, [double defaultVal = 0.0]) {
        final str = getString(keys);
        if (str.isEmpty) return defaultVal;
        final clean = str.replaceAll(RegExp(r'[^\d.]'), '');
        return double.tryParse(clean) ?? defaultVal;
      }

      final name = getString(['productname', 'name', 'itemname', 'item']);
      if (name.isEmpty) {
        errors.add('Missing Product Name');
      }

      final sellingPriceStr = getString(['sellingprice', 'price', 'rate', 'sp']);
      if (sellingPriceStr.isEmpty) {
        errors.add('Missing Selling Price');
      }
      final sellingPrice = getDouble(['sellingprice', 'price', 'rate', 'sp']);
      if (sellingPrice < 0) {
        errors.add('Invalid Selling Price');
      }

      final purchasePrice = getDouble(['purchaseprice', 'costprice', 'cp', 'cost']);
      final mrp = getDouble(['mrp', 'maxretailprice'], sellingPrice);
      final discount = getDouble(['discount', 'disc']);
      final gstRate = getDouble(['gst', 'gst%', 'tax', 'taxrate']);
      final openingStock = getDouble(['openingstock', 'stock', 'qty', 'quantity']);
      final minStock = getDouble(['minimumstock', 'minstock', 'lowstock'], 5.0);

      final sku = getString(['productcode', 'sku', 'code', 'itemcode'], IdGenerator.generateId('sku'));
      final barcode = getString(['barcode', 'upc', 'ean']);
      final category = getString(['category', 'cat'], 'General');
      final subcategory = getString(['subcategory', 'subcat']);
      final brand = getString(['brand']);
      final unit = getString(['unit', 'uom'], 'Pcs');
      final supplier = getString(['supplier', 'vendor']);
      final batch = getString(['batch', 'batchno']);
      final expiryDate = getString(['expirydate', 'expiry', 'exp']);
      final notes = getString(['notes', 'description', 'desc']);

      bool isDuplicate = false;
      if (barcode.isNotEmpty) {
        final bLower = barcode.toLowerCase();
        if (existingBarcodes.contains(bLower) || seenInFileBarcodes.contains(bLower)) {
          isDuplicate = true;
          errors.add('Duplicate Barcode: $barcode');
        } else {
          seenInFileBarcodes.add(bLower);
        }
      }

      if (sku.isNotEmpty) {
        final sLower = sku.toLowerCase();
        if (existingSkus.contains(sLower) || seenInFileSkus.contains(sLower)) {
          isDuplicate = true;
          errors.add('Duplicate Product Code: $sku');
        } else {
          seenInFileSkus.add(sLower);
        }
      }

      Product? product;
      if (errors.isEmpty) {
        final now = DateTime.now();
        product = Product(
          id: IdGenerator.generateId('prod'),
          sku: sku,
          barcode: barcode,
          name: name,
          category: category,
          subcategory: subcategory.isNotEmpty ? subcategory : null,
          brand: brand.isNotEmpty ? brand : null,
          unit: unit,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          mrp: mrp > 0 ? mrp : sellingPrice,
          discount: discount,
          gstRate: gstRate,
          currentStock: openingStock,
          minStock: minStock,
          supplierId: supplier.isNotEmpty ? supplier : null,
          batch: batch.isNotEmpty ? batch : null,
          expiryDate: expiryDate.isNotEmpty ? expiryDate : null,
          notes: notes.isNotEmpty ? notes : null,
          createdAt: now,
          updatedAt: now,
        );
      }

      final rowResult = ImportRowResult(
        rowIndex: r + 1,
        rawData: rawData,
        product: product,
        isValid: errors.isEmpty && product != null,
        isDuplicate: isDuplicate,
        errors: errors,
      );

      if (isDuplicate) {
        duplicateList.add(rowResult);
      } else if (rowResult.isValid) {
        validList.add(rowResult);
      } else {
        invalidList.add(rowResult);
      }
    }

    return ImportAnalysis(
      totalRows: rows.length - 1,
      validRows: validList,
      invalidRows: invalidList,
      duplicateRows: duplicateList,
      detectedHeaders: headers,
      missingRequiredHeaders: missingReqs,
    );
  }

  static String _normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }
}
