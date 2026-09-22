import 'package:flutter/material.dart';

import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/insights_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_alert_banner.dart';
import '../widgets/summary_pills.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_card.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
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
              _SmartTip(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
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


/// A compact "smart tip" card showing the single highest-priority insight,
/// tapping through to the full Insights screen. Renders nothing when there's
/// nothing worth surfacing.
class _SmartTip extends StatelessWidget {
  const _SmartTip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final insights = InsightsEngine.analyze(
      TransactionRepository.instance.all,
      budgets: BudgetRepository.instance.all,
    );
    if (insights.isEmpty) return const SizedBox.shrink();
    final top = insights.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart tip',
                        style: TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        top.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textOnDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textOnDarkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
