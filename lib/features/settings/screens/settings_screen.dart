import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/shop_type.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/scanzo_logo.dart';
import '../../../app/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessRepo = BusinessRepository();
  final _settingsRepo = SettingsRepository();
  final _authRepo = AuthRepository();

  BusinessProfile? _business;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _business = _businessRepo.getBusinessProfile();
      _settings = _settingsRepo.getSettings();
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out of Scanzo?'),
        content: const Text('Your store data and inventory will remain safe on this device. You will need to log in with your phone number to access it again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authRepo.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
    }
  }

  Future<void> _handleResetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Store Data?'),
        content: const Text('WARNING: This will permanently delete all products, bills, customers, and inventory records. This action cannot be reversed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, Erase Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _settingsRepo.resetAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All store data has been cleared.')),
      );
      _loadSettings();
    }
  }

  void _showStoreSwitcher() {
    final stores = _businessRepo.getAllStores();
    final activeId = _businessRepo.activeStoreId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryPinkDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Switch Active Store', style: AppTypography.h3.copyWith(fontSize: 18)),
                        Text('Independent inventory, sales & reports per store', style: AppTypography.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: stores.length,
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      final isSelected = store.id == activeId;
                      final type = ShopType.getById(store.shopTypeId);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? type.pastelColor.withOpacity(0.5) : AppColors.backgroundCream,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? type.darkColor : AppColors.borderLight,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceWhite : type.pastelColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(type.icon, color: type.darkColor, size: 22),
                          ),
                          title: Text(
                            store.businessName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${type.title} • Store ID: ${store.id}',
                            style: AppTypography.caption,
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: type.darkColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!isSelected) {
                              await _businessRepo.setActiveStore(store.id);
                              _loadSettings();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Switched to ${store.businessName} (${type.title})'),
                                    backgroundColor: AppColors.primaryPinkDark,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateStoreDialog();
                  },
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('+ Add New Shop / Business Type'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.primaryPinkDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateStoreDialog() {
    String selectedType = 'clothing';
    final nameController = TextEditingController(text: 'Fashion Boutique');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentType = ShopType.getById(selectedType);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_business_rounded, color: AppColors.primaryPinkDark),
                SizedBox(width: 8),
                Text('Add New Store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Business Category:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ShopType.standardShopTypes.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Row(
                          children: [
                            Icon(t.icon, size: 18, color: t.darkColor),
                            const SizedBox(width: 8),
                            Text(t.title, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          final t = ShopType.getById(val);
                          nameController.text = '${t.title} Scanzo';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Store Name:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Category: ${currentType.performanceBadge} • ${currentType.benchmarkTurnover}',
                    style: TextStyle(fontSize: 12, color: currentType.darkColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogCtx);
                  final newStore = await _businessRepo.createOrGetStoreForShopType(
                    selectedType,
                    storeName: name,
                  );
                  await _businessRepo.setActiveStore(newStore.id);
                  _loadSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created & switched to $name (${ShopType.getById(selectedType).title})'),
                        backgroundColor: AppColors.primaryPinkDark,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPinkDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create & Open', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpiConfigDialog() {
    final controller = TextEditingController(text: _business?.upiId ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_rounded, color: AppColors.mintGreenDark),
            SizedBox(width: 8),
            Text('Configure Store UPI ID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your business UPI ID (VPA) to accept payments via GPay, PhonePe, Paytm QR:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g. storename@okaxis, 9876543210@upi',
                filled: true,
                fillColor: AppColors.backgroundCream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _businessRepo.updateStoreUpiId(controller.text.trim());
              _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Store UPI ID updated successfully!'),
                    backgroundColor: AppColors.primaryPinkDark,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: const Text('Save UPI ID', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShopType = ShopType.getById(_businessRepo.activeStoreType);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Business Profile Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: activeShopType.pastelColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeShopType.darkColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(activeShopType.icon, size: 30, color: activeShopType.darkColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _business?.businessName ?? 'SCANZO Store',
                        style: AppTypography.h3.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activeShopType.title} • ${_business?.mobile ?? ''}',
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: activeShopType.darkColor),
                      ),
                      if (_business?.gstin != null)
                        Text('GSTIN: ${_business!.gstin}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: activeShopType.darkColor),
                  tooltip: 'Edit Store Details',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.businessDetails).then((_) => _loadSettings()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Settings Section: Multi-Store Management
          _buildSettingsGroup(
            title: 'Store & Shop Type Management',
            items: [
              _buildSettingTile(
                icon: Icons.swap_horiz_rounded,
                iconColor: AppColors.primaryPinkDark,
                title: 'Switch Active Store',
                subtitle: '${_business?.businessName ?? 'Current Shop'} (${activeShopType.title})',
                onTap: _showStoreSwitcher,
              ),
              _buildSettingTile(
                icon: Icons.add_business_rounded,
                iconColor: AppColors.mintGreenDark,
                title: 'Add Another Shop / Category',
                subtitle: 'Retail, Pharmacy, Electronics, Fashion, Grocery & more',
                onTap: _showCreateStoreDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Settings Section: Preferences
          _buildSettingsGroup(
            title: 'Store Preferences',
            items: [
              _buildSettingTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.pastelLavenderDark,
                title: 'Default Receipt Format',
                subtitle: _settings.defaultReceiptFormat,
                onTap: () {
                  _showFormatPicker();
                },
              ),
              _buildSettingTile(
                icon: Icons.percent_rounded,
                iconColor: AppColors.softPeachDark,
                title: 'Tax & GST Settings',
                subtitle: _settings.enableGst ? 'GST Active (${_settings.defaultGstRate.toInt()}%)' : 'GST Disabled',
                onTap: () => Navigator.pushNamed(context, AppRoutes.businessDetails).then((_) => _loadSettings()),
              ),
              _buildSettingTile(
                icon: Icons.qr_code_rounded,
                iconColor: AppColors.mintGreenDark,
                title: 'Store UPI & QR Payment ID',
                subtitle: (_business != null && _business!.upiId.isNotEmpty)
                    ? 'Active UPI ID: ${_business!.upiId}'
                    : 'Tap to configure UPI ID for GPay & PhonePe payments',
                onTap: _showUpiConfigDialog,
              ),
              _buildSettingTile(
                icon: Icons.notification_important_outlined,
                iconColor: AppColors.softRoseDark,
                title: 'Low Stock Alerts',
                subtitle: _settings.enableLowStockAlerts ? 'Alerts Enabled (Threshold: ${_settings.defaultLowStockThreshold.toInt()})' : 'Disabled',
                trailing: Switch(
                  value: _settings.enableLowStockAlerts,
                  activeColor: AppColors.primaryPinkDark,
                  onChanged: (val) async {
                    final updated = _settings.copyWith(enableLowStockAlerts: val);
                    await _settingsRepo.saveSettings(updated);
                    _loadSettings();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Settings Section: Data & Backup
          _buildSettingsGroup(
            title: 'Data & Security',
            items: [
              _buildSettingTile(
                icon: Icons.cloud_download_rounded,
                iconColor: AppColors.babyBlueDark,
                title: 'Backup & Restore Database',
                subtitle: 'Export complete JSON backup or restore',
                onTap: () => Navigator.pushNamed(context, AppRoutes.backupRestore),
              ),
              _buildSettingTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.error,
                title: 'Erase All Store Data',
                subtitle: 'Clear products, sales and customer history',
                onTap: _handleResetAllData,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Settings Section: About & Session
          _buildSettingsGroup(
            title: 'Application',
            items: [
              _buildSettingTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.mintGreenDark,
                title: 'About ${AppConstants.appName}',
                subtitle: '${AppConstants.appTagline} • v${AppConstants.appVersion}',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationIcon: const ScanzoLogo.badge(size: 48),
                    applicationName: AppConstants.appName,
                    applicationVersion: AppConstants.appVersion,
                    applicationLegalese: 'SCANZO - Smart Billing & Business Management.\nOffline-first point of sale system.',
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: 'Log Out',
                subtitle: 'Safely close session on this device',
                onTap: _handleLogout,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Official Branding Footer
          Center(
            child: Column(
              children: [
                const ScanzoLogo.badge(size: 52),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appName,
                  style: AppTypography.h3.copyWith(fontSize: 16),
                ),
                Text(
                  AppConstants.appTagline,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConstants.appVersion} • All data stored locally on this device',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Default Receipt Print Format', style: AppTypography.h3),
            const SizedBox(height: 12),
            ...AppConstants.receiptFormats.map((f) {
              final isSel = _settings.defaultReceiptFormat == f;
              return ListTile(
                title: Text(f, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                trailing: isSel ? const Icon(Icons.check, color: AppColors.primaryPinkDark) : null,
                onTap: () async {
                  final updated = _settings.copyWith(defaultReceiptFormat: f);
                  await _settingsRepo.saveSettings(updated);
                  Navigator.pop(ctx);
                  _loadSettings();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(title, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
