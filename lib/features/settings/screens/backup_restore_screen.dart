import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../data/repositories/settings_repository.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _settingsRepo = SettingsRepository();
  bool _isLoading = false;

  void _exportBackup() {
    final jsonString = _settingsRepo.exportBackupJson();
    Clipboard.setData(ClipboardData(text: jsonString));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Backup Created'),
          ],
        ),
        content: const Text(
          'Complete database backup has been copied to your clipboard. You can paste it into a file or share it securely.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(jsonString, subject: 'SCANZO_Backup_${DateTime.now().millisecondsSinceEpoch}.json');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: const Text('Share File Text', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final textController = TextEditingController();
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Paste Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the JSON content of your previous SCANZO backup:'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{\n  "version": "1.0.0",\n  ...\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != null && confirm.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _settingsRepo.importBackupJson(confirm);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database restored successfully!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup JSON format: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.babyBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.backup_rounded, color: AppColors.babyBlueDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export Database Backup', style: AppTypography.h3.copyWith(fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('Save all products, sales, stock, and customers', style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ScanzoButton(
                    text: 'Generate & Copy Backup JSON',
                    onPressed: _exportBackup,
                    icon: Icons.download_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.mintGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.mintGreenDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Restore from Backup', style: AppTypography.h3.copyWith(fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('Import previously saved database JSON', style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ScanzoButton(
                    text: 'Restore Backup JSON',
                    onPressed: _restoreBackup,
                    isLoading: _isLoading,
                    isOutlined: true,
                    icon: Icons.upload_file_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
