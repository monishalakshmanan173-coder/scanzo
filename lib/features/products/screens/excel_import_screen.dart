import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/excel_import_service.dart';
import '../../../data/database/database_helper.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> with SingleTickerProviderStateMixin {
  final _productRepo = ProductRepository();
  late TabController _tabController;

  String? _selectedFileName;
  ImportAnalysis? _analysis;
  bool _isLoading = false;
  bool _isImporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Unable to read file content. Please try another file.');
        }

        final currentStoreId = _productRepo.activeStoreId;
        final existing = _productRepo.getAllProducts(storeId: currentStoreId);
        final analysis = ExcelImportService.parseAndAnalyze(
          bytes: bytes,
          fileName: file.name,
          existingProducts: existing,
          storeId: currentStoreId,
        );

        setState(() {
          _selectedFileName = file.name;
          _analysis = analysis;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadSampleData() {
    final currentStoreId = _productRepo.activeStoreId;
    final currentStoreType = DatabaseHelper().activeStoreType;
    final sampleCsv = ExcelImportService.generateSampleCsv(currentStoreType);
    final bytes = utf8.encode(sampleCsv);
    final existing = _productRepo.getAllProducts(storeId: currentStoreId);

    final analysis = ExcelImportService.parseAndAnalyze(
      bytes: Uint8List.fromList(bytes),
      fileName: 'scanzo_${currentStoreType}_sample.csv',
      existingProducts: existing,
      storeId: currentStoreId,
    );

    setState(() {
      _selectedFileName = 'scanzo_${currentStoreType}_sample.csv';
      _analysis = analysis;
    });
  }

  void _copySampleCsv() {
    final currentStoreType = DatabaseHelper().activeStoreType;
    final sample = ExcelImportService.generateSampleCsv(currentStoreType);
    Clipboard.setData(ClipboardData(text: sample));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sample CSV for ${DatabaseHelper().activeStoreName} copied to clipboard!')),
    );
  }

  Future<void> _confirmAndImport() async {
    if (_analysis == null || _analysis!.validRows.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final currentStoreId = _productRepo.activeStoreId;
      final validProducts = _analysis!.validRows
          .where((r) => r.product != null)
          .map((r) => r.product!.copyWith(storeId: currentStoreId))
          .toList();

      await _productRepo.bulkInsertProducts(validProducts, storeId: currentStoreId);

      if (!mounted) return;

      // Show Import Summary Dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              const SizedBox(width: 10),
              const Text('Import Summary'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Target Store:', DatabaseHelper().activeStoreName),
              _buildSummaryRow('Total Rows in File:', '${_analysis!.totalRows}'),
              _buildSummaryRow('Successfully Imported:', '${validProducts.length}', AppColors.success),
              _buildSummaryRow('Invalid / Missing Fields:', '${_analysis!.invalidRows.length}', AppColors.error),
              _buildSummaryRow('Duplicates Skipped:', '${_analysis!.duplicateRows.length}', AppColors.warning),
              const SizedBox(height: 12),
              Text('All valid products have been safely added to ${DatabaseHelper().activeStoreName}.'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return to products list
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
              child: const Text('Go to Product List', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to bulk import products: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Widget _buildSummaryRow(String label, String value, [Color? valColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStoreName = DatabaseHelper().activeStoreName;
    final activeStoreType = DatabaseHelper().activeStoreType.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Import Products (Excel/CSV)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Copy Sample CSV Format',
            onPressed: _copySampleCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Store Indicator
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.softPeach,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.softPeachDark.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18, color: AppColors.softPeachDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target Store: $activeStoreName ($activeStoreType)',
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Top Action Card: File Picker & Sample Loader
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.softAqua,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: AppColors.softAquaDark, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName ?? 'Select CSV or Excel (.xlsx) file',
                            style: AppTypography.h3.copyWith(fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bulk upload product catalog, prices & stock',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ScanzoButton(
                        text: 'Choose File',
                        onPressed: _isLoading ? null : _pickFile,
                        isLoading: _isLoading,
                        icon: Icons.folder_open_rounded,
                        height: 42,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ScanzoButton(
                        text: 'Try Sample CSV',
                        onPressed: _loadSampleData,
                        isOutlined: true,
                        icon: Icons.science_outlined,
                        height: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMessage!, style: AppTypography.caption.copyWith(color: AppColors.error)),
              ),
            ),

          // Analysis Tabs
          if (_analysis != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primaryPinkDark,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                tabs: [
                  Tab(text: 'Valid (${_analysis!.validRows.length})'),
                  Tab(text: 'Invalid (${_analysis!.invalidRows.length})'),
                  Tab(text: 'Duplicates (${_analysis!.duplicateRows.length})'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRowsList(_analysis!.validRows, isInvalid: false),
                  _buildRowsList(_analysis!.invalidRows, isInvalid: true),
                  _buildRowsList(_analysis!.duplicateRows, isInvalid: true),
                ],
              ),
            ),

            // Bottom Confirmation Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ready to Import: ${_analysis!.validRows.length} items',
                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_analysis!.invalidRows.length + _analysis!.duplicateRows.length} issues detected',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ScanzoButton(
                      text: 'Confirm & Import',
                      onPressed: _analysis!.canProceed ? _confirmAndImport : null,
                      isLoading: _isImporting,
                      icon: Icons.check_rounded,
                      height: 46,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Expanded(
              child: EmptyStateView(
                icon: Icons.file_upload_outlined,
                title: 'No File Selected',
                message: 'Select a CSV or XLSX file to preview, validate columns and import into your inventory.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowsList(List<ImportRowResult> rows, {required bool isInvalid}) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          isInvalid ? 'No issues found!' : 'No valid items in this file.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final prod = row.product;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInvalid ? AppColors.error.withOpacity(0.3) : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Row #${row.rowIndex}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                  if (row.isValid)
                    const StatusBadge(text: 'Valid', type: BadgeType.success)
                  else if (row.isDuplicate)
                    const StatusBadge(text: 'Duplicate', type: BadgeType.warning)
                  else
                    const StatusBadge(text: 'Invalid', type: BadgeType.error),
                ],
              ),
              const SizedBox(height: 6),

              if (prod != null) ...[
                Text(prod.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Selling: ${CurrencyFormatter.format(prod.sellingPrice)} • Stock: ${prod.currentStock.toStringAsFixed(0)} ${prod.unit} • ${prod.category}',
                  style: AppTypography.caption,
                ),
              ] else ...[
                Text(
                  row.rawData['Product Name']?.toString() ?? 'Unknown item',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],

              if (row.errors.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: row.errors.map((err) {
                      return Row(
                        children: [
                          const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(err, style: AppTypography.caption.copyWith(color: AppColors.error)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
