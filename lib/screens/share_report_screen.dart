import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/transaction_repository.dart';
import '../services/report_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/report_card.dart';

/// Shows a branded, shareable report card and lets the user share it as an
/// image (viral growth loop). Users can toggle between this month and last.
class ShareReportScreen extends StatefulWidget {
  const ShareReportScreen({super.key});

  @override
  State<ShareReportScreen> createState() => _ShareReportScreenState();
}

class _ShareReportScreenState extends State<ShareReportScreen> {
  final GlobalKey _cardKey = GlobalKey();
  int _monthsAgo = 0;
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) return;
      final file = XFile.fromData(
        bytes,
        name: 'spendly-report.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        [file],
        text: 'My Spendly money report 💸 — track your spends automatically. '
            '#Spendly',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List?> _capturePng() async {
    final boundary = _cardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final report =
        ReportBuilder.forMonth(TransactionRepository.instance.all, monthsAgo: _monthsAgo);

    return Scaffold(
      appBar: AppBar(title: const Text('Share report')),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          _MonthToggle(
            monthsAgo: _monthsAgo,
            onChanged: (v) => setState(() => _monthsAgo = v),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ReportCard(report: report),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Icon(Icons.share_rounded),
                label: Text(_sharing ? 'Preparing…' : 'Share my report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthToggle extends StatelessWidget {
  const _MonthToggle({required this.monthsAgo, required this.onChanged});

  final int monthsAgo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          children: [
            _seg('This month', 0),
            _seg('Last month', 1),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, int value) {
    final selected = monthsAgo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOnDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
