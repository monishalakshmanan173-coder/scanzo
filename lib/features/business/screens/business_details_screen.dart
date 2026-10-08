import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/scanzo_text_field.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../app/routes.dart';

class BusinessDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const BusinessDetailsScreen({super.key, this.arguments});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessRepo = BusinessRepository();
  final _authRepo = AuthRepository();

  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _gstinController;
  late TextEditingController _invoicePrefixController;

  bool _isGstEnabled = true;
  double _defaultGstRate = 5.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = _authRepo.currentUser;
    final existingProfile = _businessRepo.getBusinessProfile();

    _businessNameController = TextEditingController(
      text: existingProfile?.businessName ?? user?.businessName ?? '',
    );
    _ownerNameController = TextEditingController(
      text: existingProfile?.ownerName ?? user?.ownerName ?? '',
    );
    _mobileController = TextEditingController(
      text: existingProfile?.mobile ?? user?.mobile ?? '',
    );
    _emailController = TextEditingController(
      text: existingProfile?.email ?? user?.email ?? '',
    );
    _addressController = TextEditingController(text: existingProfile?.address ?? '');
    _cityController = TextEditingController(text: existingProfile?.city ?? '');
    _stateController = TextEditingController(text: existingProfile?.state ?? '');
    _pincodeController = TextEditingController(text: existingProfile?.pincode ?? '');
    _gstinController = TextEditingController(text: existingProfile?.gstin ?? '');
    _invoicePrefixController = TextEditingController(
      text: existingProfile?.invoicePrefix ?? AppConstants.defaultInvoicePrefix,
    );

    if (existingProfile != null) {
      _isGstEnabled = existingProfile.isGstEnabled;
      _defaultGstRate = existingProfile.defaultGstRate;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _gstinController.dispose();
    _invoicePrefixController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveBusiness() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final shopTypeId = widget.arguments?['shopTypeId'] ?? 'retail';
      final existing = _businessRepo.getBusinessProfile();

      final profile = BusinessProfile(
        id: existing?.id ?? IdGenerator.generateId('biz'),
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        gstin: _gstinController.text.trim().isNotEmpty ? _gstinController.text.trim().toUpperCase() : null,
        invoicePrefix: _invoicePrefixController.text.trim().toUpperCase(),
        currency: '₹',
        isGstEnabled: _isGstEnabled,
        defaultGstRate: _defaultGstRate,
        shopTypeId: shopTypeId,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _businessRepo.saveBusinessProfile(profile);
      await _authRepo.completeBusinessSetup();

      if (!mounted) return;
      // All setup finished -> Go directly to Dashboard!
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (r) => false);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Store & Billing Setup'),
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

                    // Basic Business Info Card
                    _buildSectionHeader('Store Identity', Icons.storefront_rounded, AppColors.softPeachDark),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          ScanzoTextField(
                            label: 'Store / Business Name *',
                            hint: 'e.g. Scanzo Supermarket',
                            controller: _businessNameController,
                            validator: (v) => Validators.validateRequired(v, 'Store name'),
                          ),
                          const SizedBox(height: 12),
                          ScanzoTextField(
                            label: 'Owner Name *',
                            hint: 'e.g. Ramesh Kumar',
                            controller: _ownerNameController,
                            validator: (v) => Validators.validateRequired(v, 'Owner name'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ScanzoTextField(
                                  label: 'Contact Mobile *',
                                  hint: '9876543210',
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  validator: Validators.validateMobile,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ScanzoTextField(
                                  label: 'Email (Optional)',
                                  hint: 'store@scanzo.in',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: Validators.validateEmail,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Location / Address Info Card
                    _buildSectionHeader('Address & Location', Icons.location_on_rounded, AppColors.babyBlueDark),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          ScanzoTextField(
                            label: 'Street Address *',
                            hint: 'Shop #12, Market Road, Near Gandhi Statue',
                            controller: _addressController,
                            validator: (v) => Validators.validateRequired(v, 'Address'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ScanzoTextField(
                                  label: 'City / Town *',
                                  hint: 'Bengaluru',
                                  controller: _cityController,
                                  validator: (v) => Validators.validateRequired(v, 'City'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ScanzoTextField(
                                  label: 'State *',
                                  hint: 'Karnataka',
                                  controller: _stateController,
                                  validator: (v) => Validators.validateRequired(v, 'State'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ScanzoTextField(
                                  label: 'Pincode *',
                                  hint: '560001',
                                  controller: _pincodeController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => Validators.validateRequired(v, 'Pincode'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tax & Billing Settings Card
                    _buildSectionHeader('Billing & Tax Settings', Icons.receipt_long_rounded, AppColors.pastelLavenderDark),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ScanzoTextField(
                                  label: 'Invoice Prefix',
                                  hint: 'SCZ',
                                  controller: _invoicePrefixController,
                                  validator: (v) => Validators.validateRequired(v, 'Invoice prefix'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: ScanzoTextField(
                                  label: 'GSTIN (Optional)',
                                  hint: '29ABCDE1234F1Z5',
                                  controller: _gstinController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Enable GST on Billing', style: AppTypography.bodyMedium),
                            subtitle: Text('Add GST breakdown to printed receipts', style: AppTypography.caption),
                            value: _isGstEnabled,
                            activeColor: AppColors.primaryPinkDark,
                            onChanged: (val) => setState(() => _isGstEnabled = val),
                          ),

                          if (_isGstEnabled) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Default GST Rate:', style: AppTypography.bodySmall),
                                Wrap(
                                  spacing: 8,
                                  children: AppConstants.standardGstRates.map((rate) {
                                    final isSelected = _defaultGstRate == rate;
                                    return ChoiceChip(
                                      label: Text('${rate.toInt()}%'),
                                      selected: isSelected,
                                      selectedColor: AppColors.primaryPink,
                                      onSelected: (selected) {
                                        if (selected) setState(() => _defaultGstRate = rate);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    ScanzoButton(
                      text: 'Complete Setup & Launch Dashboard',
                      onPressed: _handleSaveBusiness,
                      isLoading: _isLoading,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
