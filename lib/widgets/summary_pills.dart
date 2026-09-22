import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The Income / Expense pill pair shown under the wallet card.
class SummaryPills extends StatelessWidget {
  const SummaryPills({
    super.key,
    required this.incomePercent,
    required this.expensePercent,
  });

  final double incomePercent;
  final double expensePercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(
            icon: Icons.arrow_outward_rounded,
            label: 'Income',
            percent: incomePercent,
            iconColor: AppColors.income,
            iconBg: AppColors.incomeSoft,
            percentColor: AppColors.income,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Pill(
            icon: Icons.south_west_rounded,
            label: 'Expense',
            percent: -expensePercent,
            iconColor: AppColors.expense,
            iconBg: AppColors.expenseSoft,
            percentColor: AppColors.expense,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.percent,
    required this.iconColor,
    required this.iconBg,
    required this.percentColor,
  });

  final IconData icon;
  final String label;
  final double percent;
  final Color iconColor;
  final Color iconBg;
  final Color percentColor;

  @override
  Widget build(BuildContext context) {
    final sign = percent >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$sign${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: percentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
