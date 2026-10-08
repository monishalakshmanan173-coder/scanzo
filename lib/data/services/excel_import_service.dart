import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
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

  /// Dynamically generates sample CSV suited specifically for the selected store type
  static String generateSampleCsv([String? shopTypeId]) {
    final type = (shopTypeId ?? DatabaseHelper().activeStoreType).toLowerCase();
    final buffer = StringBuffer();
    buffer.writeln(
        'Product Code,Product Name,Category,Subcategory,Brand,Barcode,Unit,Purchase Price,Selling Price,MRP,Discount,GST %,Opening Stock,Minimum Stock,Supplier,Batch,Expiry Date,Notes');

    if (type == 'electronics') {
      buffer.writeln(
          'ELEC-101,Bluetooth Wireless Headphones,Audio,Headphones,Boat,8901234100101,Pcs,899.00,1499.00,1999.00,0,18,45,10,Boat Direct,BT2026,2028-12-31,Deep bass stereo');
      buffer.writeln(
          'ELEC-102,Fast USB-C Charger 65W,Accessories,Charger,Anker,8901234100102,Pcs,650.00,1299.00,1499.00,0,18,60,15,Anker India,ANK01,,GaN fast charging');
      buffer.writeln(
          'ELEC-103,Braided USB-C Cable 1.5m,Accessories,Cables,Portronics,8901234100103,Pcs,120.00,299.00,399.00,0,18,100,20,Portronics Hub,CBL99,,Durable nylon');
      buffer.writeln(
          'ELEC-104,Power Bank 20000mAh Dual Port,Power,Power Bank,Mi,8901234100104,Pcs,1200.00,1999.00,2499.00,0,18,30,8,Mi Dist,PB02,,18W quick charge');
      buffer.writeln(
          'ELEC-105,Portable Bluetooth Speaker,Audio,Speakers,JBL,8901234100105,Pcs,1600.00,2499.00,2999.00,0,18,25,5,JBL Audio,SPK44,,Waterproof IPX7');
    } else if (type == 'clothing' || type == 'fashion') {
      buffer.writeln(
          'FASH-101,Premium Cotton Crew T-Shirt,Menswear,T-Shirt,Levis,8902234100201,Pcs,350.00,699.00,899.00,0,5,50,15,Levis Apparel,T26,2029-01-01,100% bio-wash cotton');
      buffer.writeln(
          'FASH-102,Slim Fit Stretch Denim Jeans,Menswear,Jeans,Wrangler,8902234100202,Pcs,1100.00,1899.00,2299.00,0,12,35,10,Denim Corp,J09,,Mid-rise dark wash');
      buffer.writeln(
          'FASH-103,Floral Casual Summer Dress,Womenswear,Dress,Zara,8902234100203,Pcs,850.00,1499.00,1999.00,0,12,25,8,Fashion Hub,D45,,Breathable rayon');
      buffer.writeln(
          'FASH-104,Silk Blend Traditional Saree,Ethnic,Saree,FabIndia,8902234100204,Pcs,1800.00,2999.00,3499.00,0,5,20,5,Ethnic Silk,S01,,With blouse piece');
      buffer.writeln(
          'FASH-105,Casual Linen Full Sleeve Shirt,Menswear,Shirt,Allen Solly,8902234100205,Pcs,750.00,1299.00,1599.00,0,5,40,12,Solly Store,SH88,,Pre-washed linen');
    } else if (type == 'medical' || type == 'pharmacy') {
      buffer.writeln(
          'MED-101,Paracetamol 500mg Strip,Medicines,Pain Relief,Cipla,8903234100301,Strip,18.00,30.00,35.00,0,12,200,40,Cipla Pharma,BATCH-P5,2027-11-30,Antipyretic');
      buffer.writeln(
          'MED-102,Vitamin C + Zinc Chewable,Wellness,Supplements,Abbott,8903234100302,Bottle,75.00,120.00,140.00,0,12,80,20,Abbott Direct,VC-2026,2027-08-31,Immunity booster');
      buffer.writeln(
          'MED-103,Waterproof Antiseptic Bandages,First Aid,Bandages,Dettol,8903234100303,Pack,50.00,85.00,95.00,0,12,150,30,Dettol Med,BNDG01,2028-06-30,Pack of 20');
      buffer.writeln(
          'MED-104,Hand Sanitizer Gel 500ml,Hygiene,Sanitizer,Lifebuoy,8903234100304,Bottle,90.00,150.00,165.00,0,18,60,15,HUL Supply,HS500,2027-12-31,70% alcohol');
      buffer.writeln(
          'MED-105,Ayurvedic Herbal Cough Syrup,Medicines,Syrup,Dabur,8903234100305,Bottle,60.00,95.00,110.00,0,5,75,20,Dabur India,CS-100,2027-05-31,Honey based 100ml');
    } else if (type == 'grocery') {
      buffer.writeln(
          'GROC-101,Pure Cow Milk 1L,Dairy,Milk,Amul,8905234100501,Pcs,58.00,66.00,66.00,0,0,50,10,Amul Dairy,MK01,2026-10-12,Pasteurized milk');
      buffer.writeln(
          'GROC-102,Whole Wheat Atta 10kg,Staples,Flour,Aashirvaad,8905234100502,Kg,360.00,410.00,440.00,0,5,35,10,ITC Supply,AT10,2027-06-30,100% whole wheat');
      buffer.writeln(
          'GROC-103,Iodized Crystal Salt 1kg,Staples,Salt,Tata,8905234100503,Kg,22.00,28.00,30.00,0,0,150,30,Tata Consumer,SLT99,,Vacuum evaporated');
      buffer.writeln(
          'GROC-104,Extra Virgin Olive Oil 500ml,Edible Oils,Oil,Figaro,8905234100504,Pcs,390.00,490.00,550.00,0,5,25,8,Figaro Impex,EVO50,2028-04-30,Cold pressed');
      buffer.writeln(
          'GROC-105,Organic Green Tea Bags 25s,Beverages,Tea,Tetley,8905234100505,Box,135.00,175.00,195.00,0,5,45,12,Tata Tea,GT25,2027-09-30,Rich antioxidants');
    } else if (type == 'bakery') {
      buffer.writeln(
          'BAKE-101,Chocolate Truffle Cake 500g,Cakes,Pastry,Bakery Fresh,8906234100601,Pcs,280.00,450.00,499.00,0,5,15,5,In-House,CK01,2026-10-10,Belgian dark chocolate');
      buffer.writeln(
          'BAKE-102,Fresh Butter Croissant,Pastry,Bakery,Bakery Fresh,8906234100602,Pcs,35.00,65.00,75.00,0,5,30,10,In-House,CR02,2026-10-09,French butter');
      buffer.writeln(
          'BAKE-103,100% Whole Wheat Brown Bread,Breads,Bread,Daily Bake,8906234100603,Pcs,30.00,45.00,50.00,0,0,40,15,Daily Fresh,BR03,2026-10-11,High fiber');
      buffer.writeln(
          'BAKE-104,Choco-Chip Artisanal Cookies 200g,Cookies,Snacks,Bakery Fresh,8906234100604,Pack,70.00,120.00,140.00,0,5,35,10,In-House,CC04,2026-11-30,Handmade crunchy');
      buffer.writeln(
          'BAKE-105,Cold Brew Roasted Coffee 250ml,Beverages,Cafe,Artisan Brew,8906234100605,Bottle,50.00,99.00,120.00,0,12,25,8,Coffee Roasters,CB05,2026-10-20,Single origin Arabica');
    } else if (type == 'retail') {
      buffer.writeln(
          'RET-101,Basmati Rice Premium 5kg,Foodgrains,Rice,Daawat,8904234100401,Kg,350.00,420.00,480.00,0,5,40,10,LT Foods,BR5K,2027-10-31,Aged royal grains');
      buffer.writeln(
          'RET-102,Sunflower Cooking Oil 1L Pouch,Edible Oil,Oil,Fortune,8904234100402,Pcs,115.00,135.00,150.00,0,5,80,20,Adani Wilmar,SF01,2027-04-30,Refined healthy oil');
      buffer.writeln(
          'RET-103,Digestive Multigrain Biscuits 250g,Snacks,Biscuits,Britannia,8904234100403,Pcs,35.00,45.00,50.00,0,5,120,25,Britannia Dist,DG01,2027-02-28,Fiber enriched');
      buffer.writeln(
          'RET-104,Bathing Beauty Soap Bar 4x100g,Personal Care,Soap,Dove,8904234100404,Pack,130.00,160.00,180.00,0,18,65,15,HUL Dist,DV04,2028-01-31,1/4 moisturizing cream');
      buffer.writeln(
          'RET-105,Complete Care Toothpaste 150g,Oral Care,Dental,Colgate,8904234100405,Pcs,75.00,95.00,105.00,0,18,90,20,Colgate India,CG15,2027-12-31,Anti-cavity formula');
    } else {
      buffer.writeln(
          'ITEM-101,Standard Commercial Item Alpha,General,Goods,Standard Co,8907234100701,Pcs,150.00,250.00,299.00,0,18,50,15,Direct Vendor,B01,,High utility goods');
      buffer.writeln(
          'ITEM-102,Multi-utility Pack Beta,Utility,Hardware,Apex Trade,8907234100702,Pcs,300.00,499.00,599.00,0,18,30,10,Apex Supplies,B02,,Standard packaging');
      buffer.writeln(
          'ITEM-103,Commercial Goods Gamma,Custom,Trade,Prime Supply,8907234100703,Pcs,550.00,899.00,999.00,0,18,20,8,Prime Dist,B03,,Industrial quality');
      buffer.writeln(
          'ITEM-104,Universal Supply Delta,Supplies,General,Union Wholesale,8907234100704,Pcs,800.00,1200.00,1400.00,0,18,15,5,Union Corp,B04,,Wholesale certified');
    }

    return buffer.toString();
  }

  /// Parses bytes from CSV, XLSX or XLS files and analyzes products
  static ImportAnalysis parseAndAnalyze({
    required Uint8List bytes,
    required String fileName,
    required List<Product> existingProducts,
    String? storeId,
  }) {
    final targetStoreId = storeId ?? DatabaseHelper().activeStoreId;
    List<List<dynamic>> rows = [];
    final lowerName = fileName.toLowerCase();

    // 1. Parse Excel (.xlsx / .xls) with excel package
    if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      try {
        final excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;

          for (var r in sheet.rows) {
            // Check if row is completely blank
            final rowValues = r.map((cell) => _extractCellValue(cell?.value)).toList();
            if (_isRowCompletelyEmpty(rowValues)) {
              continue; // SKIP BLANK ROWS & USED-RANGE ARTIFACTS
            }
            rows.add(rowValues);
          }

          if (rows.isNotEmpty) break; // Take first non-empty sheet
        }
      } catch (e) {
        debugPrint('Excel decode error: $e. Falling back to text parse.');
      }
    }

    // 2. Fallback to CSV / text lines if rows is still empty
    if (rows.isEmpty) {
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        final parsed = _parseCsvLine(line);
        if (!_isRowCompletelyEmpty(parsed)) {
          rows.add(parsed);
        }
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
      if (normalized.isNotEmpty) {
        headerIndexMap[normalized] = i;
      }
    }

    // Intelligent column finder matching aliases
    int? findColumnIndex(List<String> aliases) {
      // 1. Exact match with normalized header
      for (var alias in aliases) {
        final norm = _normalizeHeader(alias);
        if (headerIndexMap.containsKey(norm)) {
          return headerIndexMap[norm];
        }
      }
      // 2. Contains match (guarded to avoid sub-word false positives)
      for (var alias in aliases) {
        final norm = _normalizeHeader(alias);
        if (norm.length < 4) continue;
        for (var entry in headerIndexMap.entries) {
          if (entry.key.contains(norm)) {
            // Guard: don't match 'productcode' / 'itemcode' for 'product' / 'item' name
            if ((norm == 'product' || norm == 'item') &&
                (entry.key.contains('code') || entry.key.contains('id') || entry.key.contains('num'))) {
              continue;
            }
            return entry.value;
          }
        }
      }
      return null;
    }

    // Column Indices
    final nameIdx = findColumnIndex([
      'productname', 'product name', 'itemname', 'item name', 'name', 'product', 'item',
      'electronicname', 'electronic name', 'medicinename', 'medicine name', 'fashionitem',
      'title', 'description'
    ]);

    final priceIdx = findColumnIndex([
      'sellingprice', 'selling price', 'price', 'saleprice', 'sale price', 'sellingrate',
      'selling rate', 'rate', 'priceinr', 'price (inr)', 'sp', 'unitprice', 'unit price', 'amount'
    ]);

    final qtyIdx = findColumnIndex([
      'quantity', 'qty', 'stock', 'availablequantity', 'available quantity',
      'openingstock', 'opening stock', 'currentstock', 'current stock', 'units', 'count'
    ]);

    final barcodeCol = findColumnIndex([
      'barcode', 'barcodenumber', 'barcode number', 'ean', 'upc'
    ]);

    final skuCol = findColumnIndex([
      'productcode', 'product code', 'itemcode', 'item code', 'sku', 'code'
    ]);

    final barcodeIdx = barcodeCol ?? skuCol;
    final skuIdx = skuCol ?? barcodeCol;

    final categoryIdx = findColumnIndex(['category', 'cat', 'department', 'group']);
    final subcategoryIdx = findColumnIndex(['subcategory', 'subcat', 'sub category']);
    final brandIdx = findColumnIndex(['brand', 'make', 'manufacturer']);
    final unitIdx = findColumnIndex(['unit', 'uom', 'measure']);
    final purchasePriceIdx = findColumnIndex(['purchaseprice', 'purchase price', 'costprice', 'cost price', 'cp', 'cost']);
    final mrpIdx = findColumnIndex(['mrp', 'maxretailprice', 'maximum retail price']);
    final discountIdx = findColumnIndex(['discount', 'disc', 'discount%']);
    final gstIdx = findColumnIndex(['gst', 'gstrate', 'gst%', 'tax', 'taxrate', 'tax%']);
    final minStockIdx = findColumnIndex(['minstock', 'minimumstock', 'minimum stock', 'lowstock', 'reorder']);
    final supplierIdx = findColumnIndex(['supplier', 'vendor']);
    final batchIdx = findColumnIndex(['batch', 'batchno', 'batch number']);
    final expiryIdx = findColumnIndex(['expirydate', 'expiry date', 'expiry', 'exp', 'expdate']);
    final notesIdx = findColumnIndex(['notes', 'remark', 'remarks', 'desc']);

    // Check required columns
    final missingReqs = <String>[];
    if (nameIdx == null) missingReqs.add('Product Name');
    if (priceIdx == null) missingReqs.add('Selling Price');

    final validList = <ImportRowResult>[];
    final invalidList = <ImportRowResult>[];
    final duplicateList = <ImportRowResult>[];

    // Filter existing products by current storeId so checks are strictly store-isolated
    final storeExisting = existingProducts.where((p) => p.storeId == targetStoreId || p.storeId.isEmpty).toList();
    final existingBarcodes = storeExisting.map((p) => p.barcode.trim().toLowerCase()).where((b) => b.isNotEmpty).toSet();
    final existingSkus = storeExisting.map((p) => p.sku.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();

    final seenInFileBarcodes = <String>{};
    final seenInFileSkus = <String>{};

    int actualRowCounter = 0;

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];

      // Completely skip empty rows
      if (_isRowCompletelyEmpty(row)) continue;

      String getCellString(int? idx, [String defaultVal = '']) {
        if (idx != null && idx < row.length) {
          final val = row[idx]?.toString().trim();
          if (val != null && val.isNotEmpty) return val;
        }
        return defaultVal;
      }

      double getCellDouble(int? idx, [double defaultVal = 0.0]) {
        final str = getCellString(idx);
        if (str.isEmpty) return defaultVal;
        return _normalizePrice(str, defaultVal);
      }

      final name = getCellString(nameIdx);
      final sellingPriceStr = getCellString(priceIdx);
      final barcode = getCellString(barcodeIdx);
      final qtyStr = getCellString(qtyIdx);

      // Check if this row is an unused trailing row or formatting-only artifact
      // If it has NO product name, NO selling price, NO barcode, and NO quantity, skip it completely
      if (name.isEmpty && sellingPriceStr.isEmpty && barcode.isEmpty && qtyStr.isEmpty) {
        continue;
      }

      actualRowCounter++;
      final errors = <String>[];
      final rawData = <String, dynamic>{};

      for (int h = 0; h < headers.length && h < row.length; h++) {
        rawData[headers[h]] = row[h];
      }

      // 1. Product Name (REQUIRED)
      if (name.isEmpty) {
        errors.add('Missing Product Name');
      }

      // 2. Selling Price (REQUIRED, must be >= 0)
      if (sellingPriceStr.isEmpty) {
        errors.add('Missing Selling Price');
      }
      final sellingPrice = getCellDouble(priceIdx, -1.0);
      if (sellingPrice < 0) {
        errors.add('Invalid Selling Price ($sellingPriceStr)');
      }

      // 3. Optional Fields
      final openingStock = getCellDouble(qtyIdx, 0.0);
      final sku = getCellString(skuIdx, IdGenerator.generateId('sku'));
      final category = getCellString(categoryIdx, 'General');
      final subcategory = getCellString(subcategoryIdx);
      final brand = getCellString(brandIdx);
      final unit = getCellString(unitIdx, 'Pcs');
      final purchasePrice = getCellDouble(purchasePriceIdx, sellingPrice > 0 ? sellingPrice * 0.7 : 0.0);
      final mrp = getCellDouble(mrpIdx, sellingPrice);
      final discount = getCellDouble(discountIdx, 0.0);
      final gstRate = getCellDouble(gstIdx, 0.0);
      final minStock = getCellDouble(minStockIdx, 5.0);
      final supplier = getCellString(supplierIdx);
      final batch = getCellString(batchIdx);
      final expiryDate = getCellString(expiryIdx);
      final notes = getCellString(notesIdx);

      // Check Duplicates strictly within this store
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

      if (sku.isNotEmpty && sku != barcode) {
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
          storeId: targetStoreId, // CRITICAL: strictly assigned to current storeId
          sku: sku.isNotEmpty ? sku : IdGenerator.generateId('sku'),
          barcode: barcode,
          name: name,
          category: category,
          subcategory: subcategory.isNotEmpty ? subcategory : null,
          brand: brand.isNotEmpty ? brand : null,
          unit: unit,
          purchasePrice: purchasePrice >= 0 ? purchasePrice : 0.0,
          sellingPrice: sellingPrice,
          mrp: mrp > 0 ? mrp : sellingPrice,
          discount: discount,
          gstRate: gstRate,
          currentStock: openingStock >= 0 ? openingStock : 0.0,
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
        rowIndex: actualRowCounter,
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
      totalRows: actualRowCounter,
      validRows: validList,
      invalidRows: invalidList,
      duplicateRows: duplicateList,
      detectedHeaders: headers,
      missingRequiredHeaders: missingReqs,
    );
  }

  static String _extractCellValue(dynamic cellValue) {
    if (cellValue == null) return '';
    if (cellValue is TextCellValue) {
      final dynamic span = cellValue.value;
      final String txt = span?.text?.toString() ?? span.toString();
      return txt.trim();
    }
    if (cellValue is IntCellValue) return cellValue.value.toString();
    if (cellValue is DoubleCellValue) {
      final val = cellValue.value;
      if (val == val.roundToDouble()) return val.toInt().toString();
      return val.toString();
    }
    if (cellValue is BoolCellValue) return cellValue.value.toString();
    if (cellValue is DateCellValue) {
      return '${cellValue.year}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    }
    try {
      final dynamic inner = (cellValue as dynamic).value;
      if (inner != null) return inner.toString().trim();
    } catch (_) {}
    return cellValue.toString().trim();
  }

  static bool _isRowCompletelyEmpty(List<dynamic> row) {
    if (row.isEmpty) return true;
    for (var cell in row) {
      final str = cell?.toString().trim() ?? '';
      if (str.isNotEmpty) return false;
    }
    return true;
  }

  static double _normalizePrice(String raw, double fallback) {
    // Normalizes strings like: "₹32,990", "₹ 32,990", "32,990", "32990.00", " 32990 "
    final clean = raw
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? fallback;
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
