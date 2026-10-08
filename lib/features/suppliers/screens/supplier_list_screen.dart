import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/supplier_repository.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _supplierRepo = SupplierRepository();
  final _searchController = TextEditingController();

  List<Supplier> _allSuppliers = [];
  List<Supplier> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSuppliers() {
    setState(() {
      _allSuppliers = _supplierRepo.getAllSuppliers();
      _applySearch();
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSuppliers = _allSuppliers.where((s) {
        return query.isEmpty ||
            s.name.toLowerCase().contains(query) ||
            s.mobile.contains(query) ||
            (s.gstin != null && s.gstin!.toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _showAddEditDialog([Supplier? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final mobileController = TextEditingController(text: existing?.mobile ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final gstinController = TextEditingController(text: existing?.gstin ?? '');
    final outstandingController = TextEditingController(text: existing?.outstandingAmount.toString() ?? '0');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'Add Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScanzoTextField(
                  label: 'Supplier / Company Name *',
                  hint: 'e.g. Metro Wholesale Distributors',
                  controller: nameController,
                  validator: (v) => Validators.validateRequired(v, 'Supplier name'),
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Mobile Number *',
                  hint: '9876543210',
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validateMobile,
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'GSTIN (Optional)',
                  hint: '29ABCDE1234F1Z5',
                  controller: gstinController,
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Outstanding Payable (₹)',
                  hint: '0.00',
                  controller: outstandingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Address (Optional)',
                  hint: 'Warehouse / Supply Office',
                  controller: addressController,
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Notes (Optional)',
                  hint: 'e.g. Delivers every Monday',
                  controller: notesController,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final outstanding = double.tryParse(outstandingController.text.trim()) ?? 0.0;
                final supplier = Supplier(
                  id: existing?.id ?? IdGenerator.generateId('sup'),
                  name: nameController.text.trim(),
                  mobile: mobileController.text.trim(),
                  email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                  address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                  gstin: gstinController.text.trim().isNotEmpty ? gstinController.text.trim().toUpperCase() : null,
                  outstandingAmount: outstanding,
                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await _supplierRepo.saveSupplier(supplier);
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: Text(existing == null ? 'Save' : 'Update', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated == true) _loadSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Suppliers & Vendors'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applySearch(),
              decoration: InputDecoration(
                hintText: 'Search supplier name, mobile, GSTIN...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          Expanded(
            child: _filteredSuppliers.isEmpty
                ? EmptyStateView(
                    icon: Icons.local_shipping_outlined,
                    title: _allSuppliers.isEmpty ? 'No Suppliers Added' : 'No Matching Suppliers',
                    message: _allSuppliers.isEmpty
                        ? 'Add wholesale suppliers and vendors to track stock purchases and payables.'
                        : 'Try searching with another keyword.',
                    buttonText: _allSuppliers.isEmpty ? 'Add First Supplier' : null,
                    onButtonPressed: () => _showAddEditDialog(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _filteredSuppliers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.lightYellow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_shipping_rounded, color: AppColors.lightYellowDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(supplier.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                  Text('${supplier.mobile}${supplier.gstin != null ? ' • GST: ${supplier.gstin}' : ''}',
                                      style: AppTypography.caption),
                                  if (supplier.outstandingAmount > 0)
                                    Text(
                                      'Payable: ${CurrencyFormatter.format(supplier.outstandingAmount)}',
                                      style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                              onPressed: () => _showAddEditDialog(supplier),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryPinkDark,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Add Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
