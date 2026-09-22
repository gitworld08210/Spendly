import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/transaction_repository.dart';
import '../services/sms_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Zero-permission way to add a transaction: the user pastes one or more bank
/// / UPI SMS and Spendly parses them. This makes the app fully usable even
/// when Android blocks the SMS permission (e.g. side-loaded builds).
class PasteSmsScreen extends StatefulWidget {
  const PasteSmsScreen({super.key});

  @override
  State<PasteSmsScreen> createState() => _PasteSmsScreenState();
}

class _PasteSmsScreenState extends State<PasteSmsScreen> {
  final _ctrl = TextEditingController();
  int? _importedCount;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _ctrl.text = data!.text!;
      setState(() {});
    }
  }

  Future<void> _import() async {
    // Split on blank lines so several messages can be pasted at once.
    final blocks = _ctrl.text
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (blocks.isEmpty) {
      // Treat the whole thing as one message.
      blocks.add(_ctrl.text.trim());
    }

    var imported = 0;
    for (final block in blocks) {
      final txn = SmsParser.toTransaction(block);
      if (txn == null) continue;
      final added = await TransactionRepository.instance.addFromSms(txn);
      if (added) imported++;
    }

    setState(() => _importedCount = imported);
    if (imported > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $imported transaction(s).')),
      );
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live preview of what the parser sees.
    final preview = _ctrl.text.trim().isEmpty
        ? null
        : SmsParser.parse(_ctrl.text.trim());

    return Scaffold(
      appBar: AppBar(title: const Text('Paste SMS')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Paste a bank or UPI SMS and Spendly will read the amount, '
            'merchant and date automatically — no SMS permission needed.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Rs.289 debited from a/c XX4021 to Zomato via UPI…',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Paste from clipboard'),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.income),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Detected: ${preview.merchant} · '
                      '${preview.type.name == 'credit' ? '+' : '-'}'
                      '${Formatters.money(preview.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_ctrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.accentOrange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Couldn't detect a transaction. You can still paste "
                      'multiple messages separated by a blank line.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _ctrl.text.trim().isEmpty ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
              child: const Text('Add transaction',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          if (_importedCount == 0) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No transaction found in that text. Make sure it\'s a bank/UPI '
              'alert with an amount.',
              style: TextStyle(color: AppColors.accentRed, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
