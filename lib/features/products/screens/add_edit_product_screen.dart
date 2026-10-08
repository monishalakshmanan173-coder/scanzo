import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../app/routes.dart';

class AddEditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const AddEditProductScreen({super.key, this.arguments});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productRepo = ProductRepository();

  Product? _existingProduct;

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _subcategoryController;
  late TextEditingController _brandController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late TextEditingController _discountController;
  late TextEditingController _currentStockController;
  late TextEditingController _minStockController;
  late TextEditingController _batchController;
  late TextEditingController _expiryDateController;
  late TextEditingController _notesController;

  String _selectedCategory = 'General';
  String _selectedUnit = 'Pcs';
  double _selectedGstRate = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _existingProduct = widget.arguments?['product'] as Product?;
    final initialBarcode = widget.arguments?['initialBarcode'] as String? ?? '';

    _nameController = TextEditingController(text: _existingProduct?.name ?? '');
    _barcodeController = TextEditingController(text: _existingProduct?.barcode ?? initialBarcode);
    _skuController = TextEditingController(text: _existingProduct?.sku ?? IdGenerator.generateId('SKU'));
    _subcategoryController = TextEditingController(text: _existingProduct?.subcategory ?? '');
    _brandController = TextEditingController(text: _existingProduct?.brand ?? '');
    _purchasePriceController = TextEditingController(text: _existingProduct?.purchasePrice.toString() ?? '0.00');
    _sellingPriceController = TextEditingController(text: _existingProduct?.sellingPrice.toString() ?? '');
    _mrpController = TextEditingController(text: _existingProduct?.mrp.toString() ?? '');
    _discountController = TextEditingController(text: _existingProduct?.discount.toString() ?? '0');
    _currentStockController = TextEditingController(text: _existingProduct?.currentStock.toString() ?? '10');
    _minStockController = TextEditingController(text: _existingProduct?.minStock.toString() ?? '5');
    _batchController = TextEditingController(text: _existingProduct?.batch ?? '');
    _expiryDateController = TextEditingController(text: _existingProduct?.expiryDate ?? '');
    _notesController = TextEditingController(text: _existingProduct?.notes ?? '');

    if (_existingProduct != null) {
      _selectedCategory = _existingProduct!.category;
      _selectedUnit = _existingProduct!.unit;
      _selectedGstRate = _existingProduct!.gstRate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _subcategoryController.dispose();
    _brandController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _discountController.dispose();
    _currentStockController.dispose();
    _minStockController.dispose();
    _batchController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateRandomBarcode() {
    final randomDigits = List.generate(12, (_) => Random().nextInt(10)).join();
    setState(() => _barcodeController.text = '890$randomDigits');
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
      final mrp = double.tryParse(_mrpController.text.trim()) ?? sellingPrice;
      final purchasePrice = double.tryParse(_purchasePriceController.text.trim()) ?? 0.0;
      final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final stock = double.tryParse(_currentStockController.text.trim()) ?? 0.0;
      final minStock = double.tryParse(_minStockController.text.trim()) ?? 5.0;

      final product = Product(
        id: _existingProduct?.id ?? IdGenerator.generateId('prod'),
        sku: _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : IdGenerator.generateId('sku'),
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        category: _selectedCategory,
        subcategory: _subcategoryController.text.trim().isNotEmpty ? _subcategoryController.text.trim() : null,
        brand: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : null,
        unit: _selectedUnit,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        mrp: mrp > 0 ? mrp : sellingPrice,
        discount: discount,
        gstRate: _selectedGstRate,
        currentStock: stock,
        minStock: minStock,
        batch: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        expiryDate: _expiryDateController.text.trim().isNotEmpty ? _expiryDateController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: _existingProduct?.createdAt ?? now,
        updatedAt: now,
      );

      await _productRepo.saveProduct(product);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingProduct != null;
    final categories = _productRepo.getAllCategories();

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.caption.copyWith(color: AppColors.error),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Section 1: Identification
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.pastelLavenderDark,
                      children: [
                        ScanzoTextField(
                          label: 'Product Name *',
                          hint: 'e.g. Premium Basmati Rice 1kg',
                          controller: _nameController,
                          validator: (v) => Validators.validateRequired(v, 'Product name'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Barcode',
                                hint: 'Scan or type',
                                controller: _barcodeController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: IconButton(
                                icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryPinkDark),
                                tooltip: 'Auto generate barcode',
                                onPressed: _generateRandomBarcode,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryPinkDark),
                                tooltip: 'Scan camera barcode',
                                onPressed: () async {
                                  final scanned = await Navigator.pushNamed(context, AppRoutes.barcodeScanner) as String?;
                                  if (scanned != null && scanned.isNotEmpty) {
                                    setState(() => _barcodeController.text = scanned);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Product Code / SKU',
                                hint: 'SKU-001',
                                controller: _skuController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Brand (Optional)',
                                hint: 'e.g. India Gate',
                                controller: _brandController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Category & Unit Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: categories.any((c) => c.name == _selectedCategory) ? _selectedCategory : 'General',
                                    decoration: const InputDecoration(filled: true, fillColor: AppColors.surfaceWhite),
                                    items: categories.map((c) {
                                      return DropdownMenuItem(value: c.name, child: Text(c.name));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategory = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Unit', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedUnit,
                                    decoration: const InputDecoration(filled: true, fillColor: AppColors.surfaceWhite),
                                    items: AppConstants.productUnits.map((u) {
                                      return DropdownMenuItem(value: u, child: Text(u));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedUnit = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Pricing & Taxes
                    _buildSectionCard(
                      title: 'Pricing & Taxes',
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.softPeachDark,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Selling Price (₹) *',
                                hint: '120.00',
                                controller: _sellingPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => Validators.validatePrice(v, 'Selling price'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ScanzoTextField(
                                label: 'MRP (₹)',
                                hint: '140.00',
                                controller: _mrpController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Purchase Cost (₹)',
                                hint: '90.00',
                                controller: _purchasePriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Discount (₹)',
                                hint: '0.00',
                                controller: _discountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GST Tax Rate:', style: AppTypography.bodySmall),
                            Wrap(
                              spacing: 6,
                              children: AppConstants.standardGstRates.map((rate) {
                                final isSelected = _selectedGstRate == rate;
                                return ChoiceChip(
                                  label: Text('${rate.toInt()}%'),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryPink,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedGstRate = rate);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Inventory Levels & Stock
                    _buildSectionCard(
                      title: 'Stock & Inventory Control',
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.mintGreenDark,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Current Stock *',
                                hint: '50',
                                controller: _currentStockController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => Validators.validateRequired(v, 'Current stock'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Minimum Stock Alert',
                                hint: '5',
                                controller: _minStockController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Batch No (Optional)',
                                hint: 'BATCH-2026',
                                controller: _batchController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ScanzoTextField(
                                label: 'Expiry Date (Optional)',
                                hint: 'YYYY-MM-DD',
                                controller: _expiryDateController,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    ScanzoButton(
                      text: isEditing ? 'Update Product' : 'Save Product',
                      onPressed: _handleSave,
                      isLoading: _isLoading,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}
