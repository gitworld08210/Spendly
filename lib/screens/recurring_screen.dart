import 'package:flutter/material.dart';

import '../models/category.dart';
import '../repositories/transaction_repository.dart';
import '../services/recurring_detector.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Lists automatically-detected recurring payments (subscriptions, rent, EMIs)
/// and the total monthly commitment they represent.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = TransactionRepository.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: AnimatedBuilder(
        animation: txns,
        builder: (context, _) {
          final subs = RecurringDetector.detect(txns.all);
          final monthly = RecurringDetector.monthlyCommitment(subs);

          if (subs.isEmpty) {
            return const _Empty();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly commitment',
                      style: TextStyle(color: AppColors.textOnDarkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.money(monthly),
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${subs.length} recurring payment${subs.length == 1 ? '' : 's'} detected',
                      style: const TextStyle(
                          color: AppColors.textOnDarkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...subs.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecurringTile(sub: s),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({required this.sub});

  final RecurringSubscription sub;

  @override
  Widget build(BuildContext context) {
    final cat = Categories.byId(sub.categoryId);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cat.icon, color: cat.color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.cadenceLabel} · next ~${Formatters.date(sub.nextDate)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            Formatters.money(sub.typicalAmount),
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew_rounded,
                size: 44, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'No recurring payments detected yet.\nOnce Spendly sees the same '
              'charge a couple of times, it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
