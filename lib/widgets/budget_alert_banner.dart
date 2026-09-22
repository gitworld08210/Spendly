import 'package:flutter/material.dart';

import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// A compact banner shown on the dashboard when one or more category budgets
/// are over or near their monthly limit. Renders nothing when all is well.
class BudgetAlertBanner extends StatelessWidget {
  const BudgetAlertBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final budgets = BudgetRepository.instance;
    final txns = TransactionRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([budgets, txns]),
      builder: (context, _) {
        final alerts = budgets.alertsThisMonth();
        if (alerts.isEmpty) return const SizedBox.shrink();

        final over = alerts.where((a) => a.isOver).toList();
        final primary = over.isNotEmpty ? over.first : alerts.first;
        final isOver = primary.isOver;

        final title = isOver
            ? '${primary.category.name} budget exceeded'
            : '${primary.category.name} budget almost used';
        final detail = isOver
            ? 'You\'re over by ${Formatters.money(-primary.remaining)} this month'
            : '${Formatters.money(primary.remaining)} left this month';
        final extra = alerts.length > 1
            ? ' · +${alerts.length - 1} more'
            : '';

        final color = isOver ? AppColors.accentRed : AppColors.accentOrange;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      isOver
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title$extra',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            detail,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
