import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup_providers.dart';
import '../domain/backup_models.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Back up', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'An encrypted backup is the only export that can fully restore your data. '
            'CSV/JSON exports are for spreadsheets and interoperability only.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text('Export encrypted backup'),
            onPressed: () => _exportEncrypted(context, ref),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export CSV'),
            onPressed: () => _exportPlain(context, ref, isCsv: true),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.code),
            label: const Text('Export JSON'),
            onPressed: () => _exportPlain(context, ref, isCsv: false),
          ),
          const Divider(height: 32),
          Text('Restore', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Restoring replaces your current data. A safety copy of what you have now '
            'is made first, and nothing is changed if the restore fails.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore from encrypted backup'),
            onPressed: () => _restore(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportEncrypted(BuildContext context, WidgetRef ref) async {
    final passphrase = await _promptPassphrase(context, title: 'Set a backup passphrase');
    if (passphrase == null || passphrase.isEmpty) return;
    try {
      final result = await ref.read(backupRepositoryProvider).exportEncryptedBackup(passphrase);
      final saved = await ref.read(backupTransportProvider).save(
            bytes: result.bytes,
            suggestedFileName: result.suggestedFileName,
          );
      if (!context.mounted) return;
      _showMessage(context, saved == null ? 'Export cancelled.' : 'Backup saved.');
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Export failed: $e');
    }
  }

  Future<void> _exportPlain(BuildContext context, WidgetRef ref, {required bool isCsv}) async {
    try {
      final repo = ref.read(backupRepositoryProvider);
      final bytes = isCsv ? await repo.exportCsv() : await repo.exportJson();
      final fileName = isCsv ? 'transactions.csv' : 'finance_export.json';
      final saved = await ref.read(backupTransportProvider).save(
            bytes: bytes,
            suggestedFileName: fileName,
          );
      if (!context.mounted) return;
      _showMessage(context, saved == null ? 'Export cancelled.' : 'Exported.');
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Export failed: $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final bytes = await ref
        .read(backupTransportProvider)
        .pick(allowedExtensions: ['financebackup']);
    if (bytes == null) return;
    if (!context.mounted) return;

    final passphrase = await _promptPassphrase(context, title: 'Enter the backup passphrase');
    if (passphrase == null || passphrase.isEmpty) return;

    RestorePreview preview;
    try {
      preview = await ref.read(backupRepositoryProvider).validateBackupFile(bytes, passphrase);
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Could not read this backup: $e');
      return;
    }
    if (!context.mounted) return;

    final confirmed = await _confirmRestore(context, preview.manifest);
    if (confirmed != true) return;

    try {
      await ref.read(backupRepositoryProvider).restoreFromBackup(preview);
      if (context.mounted) _showMessage(context, 'Restore complete.');
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Restore failed: $e');
    }
  }

  Future<bool?> _confirmRestore(BuildContext context, BackupManifest manifest) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created: ${manifest.createdAt.toLocal()}'),
            Text('App version: ${manifest.appVersion}'),
            const SizedBox(height: 8),
            Text('Wallets: ${manifest.rowCounts['wallets'] ?? 0}'),
            Text('Transactions: ${manifest.rowCounts['transactions'] ?? 0}'),
            Text('Debts: ${manifest.rowCounts['debts'] ?? 0}'),
            const SizedBox(height: 8),
            const Text('This will replace all data currently on this device.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
        ],
      ),
    );
  }

  Future<String?> _promptPassphrase(BuildContext context, {required String title}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
