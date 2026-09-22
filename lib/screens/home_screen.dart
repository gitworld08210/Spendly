import 'package:flutter/material.dart';

import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_alert_banner.dart';
import '../widgets/summary_pills.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_card.dart';
import 'budgets_screen.dart';
import 'transaction_detail_screen.dart';

/// The main dashboard: greeting, wallet card, income/expense pills and a
/// list of recent transactions — matching the reference design.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month);
        final summary = repo.summaryBetween(monthStart, now);
        final recent = repo.recent(8);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120),
            children: [
              _Header(userName: userName),
              const SizedBox(height: AppSpacing.lg),
              WalletCard(
                balance: repo.balance,
                last4: '402',
                spentRatio: summary.expensePercent / 100,
              ),
              const SizedBox(height: AppSpacing.md),
              SummaryPills(
                incomePercent: summary.incomePercent,
                expensePercent: summary.expensePercent,
              ),
              const SizedBox(height: AppSpacing.lg),
              BudgetAlertBanner(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (recent.isEmpty)
                const _EmptyState()
              else
                ...recent.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TransactionTile(
                      txn: t,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(txn: t),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning!'
        : hour < 17
            ? 'Good Afternoon!'
            : 'Good Evening!';
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Icon(Icons.notifications_none_rounded,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.sms_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'No transactions yet.\nGrant SMS access and Spendly will '
            'add them automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
