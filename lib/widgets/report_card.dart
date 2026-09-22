import 'package:flutter/material.dart';

import '../services/report_builder.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// The branded card that gets rendered to an image and shared. Designed to look
/// great as a standalone WhatsApp/Instagram share (fixed, self-contained).
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final SpendReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand row.
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('S',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Spendly',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const Spacer(),
              Text(report.periodLabel,
                  style: const TextStyle(
                      color: AppColors.textOnDarkMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('My spending this month',
              style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            Formatters.money(report.expense),
            style: const TextStyle(
                color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Income',
                  value: Formatters.compactMoney(report.income),
                  color: AppColors.income,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Saved',
                  value: '${report.savingsRate.round()}%',
                  color: report.savingsRate >= 0
                      ? AppColors.income
                      : AppColors.accentRed,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Txns',
                  value: '${report.txnCount}',
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (report.topCategory != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inkSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(report.topCategory!.icon,
                      color: report.topCategory!.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Top: ${report.topCategory!.name}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(Formatters.compactMoney(report.topCategoryAmount),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Center(
            child: Text('Track spends automatically with Spendly',
                style: TextStyle(
                    color: AppColors.textOnDarkMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textOnDarkMuted, fontSize: 12)),
      ],
    );
  }
}
