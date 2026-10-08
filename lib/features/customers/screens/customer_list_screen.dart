import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/billing_repository.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _customerRepo = CustomerRepository();
  final _billingRepo = BillingRepository();
  final _searchController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCustomers() {
    setState(() {
      _allCustomers = _customerRepo.getAllCustomers();
      _applySearch();
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        return query.isEmpty ||
            c.name.toLowerCase().contains(query) ||
            c.mobile.contains(query) ||
            (c.email != null && c.email!.toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _showAddEditDialog([Customer? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final mobileController = TextEditingController(text: existing?.mobile ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScanzoTextField(
                  label: 'Customer Name *',
                  hint: 'e.g. Anjali Sharma',
                  controller: nameController,
                  validator: (v) => Validators.validateRequired(v, 'Customer name'),
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
                  label: 'Email (Optional)',
                  hint: 'anjali@example.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Address (Optional)',
                  hint: 'Street, Flat #, Area',
                  controller: addressController,
                ),
                const SizedBox(height: 10),
                ScanzoTextField(
                  label: 'Notes / Credit Limit (Optional)',
                  hint: 'Regular customer',
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
                final customer = Customer(
                  id: existing?.id ?? IdGenerator.generateId('cust'),
                  name: nameController.text.trim(),
                  mobile: mobileController.text.trim(),
                  email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                  address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                  pendingBalance: existing?.pendingBalance ?? 0.0,
                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await _customerRepo.saveCustomer(customer);
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: Text(existing == null ? 'Save' : 'Update', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated == true) _loadCustomers();
  }

  void _showCustomerHistory(Customer customer) {
    final allSales = _billingRepo.getAllSales();
    final customerSales = allSales.where((s) => s.customerId == customer.id || s.customerMobile == customer.mobile).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(customer.name, style: AppTypography.h3),
                Text('Pending: ${CurrencyFormatter.format(customer.pendingBalance)}',
                    style: TextStyle(color: customer.pendingBalance > 0 ? AppColors.error : AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('Mobile: ${customer.mobile}', style: AppTypography.caption),
            const Divider(height: 20),
            Text('Purchase History (${customerSales.length} bills)', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: customerSales.isEmpty
                  ? const Center(child: Text('No previous bills for this customer yet.'))
                  : ListView.builder(
                      itemCount: customerSales.length,
                      itemBuilder: (context, idx) {
                        final s = customerSales[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Invoice #${s.invoiceNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year} • ${s.paymentMethod}'),
                          trailing: Text(CurrencyFormatter.format(s.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Customer Accounts'),
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
                hintText: 'Search customer name or mobile...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          Expanded(
            child: _filteredCustomers.isEmpty
                ? EmptyStateView(
                    icon: Icons.people_outline_rounded,
                    title: _allCustomers.isEmpty ? 'No Customers Added' : 'No Matching Customers',
                    message: _allCustomers.isEmpty
                        ? 'Add regular customers to track credits, pending payments and purchase history.'
                        : 'Try searching with a different name or phone number.',
                    buttonText: _allCustomers.isEmpty ? 'Add First Customer' : null,
                    onButtonPressed: () => _showAddEditDialog(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
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
                                color: AppColors.softPink,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.softPinkDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                  Text(customer.mobile, style: AppTypography.caption),
                                  if (customer.pendingBalance > 0)
                                    Text(
                                      'Pending Credit: ${CurrencyFormatter.format(customer.pendingBalance)}',
                                      style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history_rounded, size: 20, color: AppColors.textSecondary),
                              tooltip: 'History',
                              onPressed: () => _showCustomerHistory(customer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                              tooltip: 'Edit',
                              onPressed: () => _showAddEditDialog(customer),
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
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
