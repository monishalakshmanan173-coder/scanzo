import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/auth_repository.dart';
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

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.warmCream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warmCreamDark.withOpacity(0.2)),
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
                  child: const Icon(Icons.storefront_rounded, size: 30, color: AppColors.warmCreamDark),
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
                        'Owner: ${_business?.ownerName ?? 'Owner'} • ${_business?.mobile ?? ''}',
                        style: AppTypography.caption,
                      ),
                      if (_business?.gstin != null)
                        Text('GSTIN: ${_business!.gstin}', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.warmCreamDark),
                  tooltip: 'Edit Store Details',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.businessDetails).then((_) => _loadSettings()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 32),
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
