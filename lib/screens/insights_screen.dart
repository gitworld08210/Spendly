import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/insight.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/ai_insights_service.dart';
import '../services/insights_engine.dart';
import '../services/pro_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/pro_lock.dart';

/// The "AI Money Coach" screen: analyzes the user's spending and shows
/// personalized, actionable insights — rule-based signals plus, when the AI is
/// configured, natural-language tips from the coach.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<AiTip>? _aiTips;
  bool _aiLoading = false;
  bool _aiRequested = false;

  Future<void> _askCoach() async {
    setState(() {
      _aiLoading = true;
      _aiRequested = true;
    });
    final tips = await AiInsightsService.instance
        .generate(TransactionRepository.instance.all);
    if (mounted) {
      setState(() {
        _aiTips = tips;
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txns = TransactionRepository.instance;
    final budgets = BudgetRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: AnimatedBuilder(
        animation: Listenable.merge([txns, budgets, ProService.instance]),
        builder: (context, _) {
          final insights =
              InsightsEngine.analyze(txns.all, budgets: budgets.all);
          final totalSaving = InsightsEngine.totalPotentialSaving(insights);

          if (insights.isEmpty) {
            return const _Empty();
          }

          final isPro = ProService.instance.isPro;
          const freeCount = 1;
          final visible = isPro ? insights : insights.take(freeCount).toList();
          final lockedCount = insights.length - visible.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
            children: [
              if (totalSaving > 0) _SavingsHeadline(amount: totalSaving),
              const SizedBox(height: AppSpacing.md),
              _AiCoachSection(
                loading: _aiLoading,
                requested: _aiRequested,
                tips: _aiTips,
                onAsk: _askCoach,
              ),
              ...visible.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InsightCard(insight: i),
                  )),
              if (lockedCount > 0)
                _LockedInsights(
                  count: lockedCount,
                  onUpgrade: () => showPaywall(context),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The AI coach block: a prompt button that, on tap, fetches natural-language
/// tips from the ai-insights function and renders them.
class _AiCoachSection extends StatelessWidget {
  const _AiCoachSection({
    required this.loading,
    required this.requested,
    required this.tips,
    required this.onAsk,
  });

  final bool loading;
  final bool requested;
  final List<AiTip>? tips;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Ask the AI coach',
                  style: TextStyle(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          if (!requested)
            const Text(
              'Get smart, personalized savings tips based on your spending.',
              style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text('Analyzing your spending…',
                      style: TextStyle(color: AppColors.textOnDarkMuted)),
                ],
              ),
            ),
          if (!loading && tips != null && tips!.isEmpty && requested)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'AI coaching isn\'t available yet. Your rule-based insights are '
                'below.',
                style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
              ),
            ),
          if (!loading && tips != null && tips!.isNotEmpty)
            ...tips!.map((t) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                style: const TextStyle(
                                    color: AppColors.textOnDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            if (t.detail.isNotEmpty)
                              Text(t.detail,
                                  style: const TextStyle(
                                      color: AppColors.textOnDarkMuted,
                                      fontSize: 13,
                                      height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          if (!loading) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(requested ? 'Refresh tips' : 'Get AI tips'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavingsHeadline extends StatelessWidget {
  const _SavingsHeadline({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, color: Colors.white, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You could save',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${Formatters.money(amount)} / month',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'by acting on the tips below',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  Color get _accent {
    switch (insight.severity) {
      case InsightSeverity.critical:
        return AppColors.accentRed;
      case InsightSeverity.warning:
        return AppColors.accentOrange;
      case InsightSeverity.positive:
        return AppColors.income;
      case InsightSeverity.info:
        return const Color(0xFF2FB1F0);
    }
  }

  IconData get _icon {
    switch (insight.kind) {
      case InsightKind.savingsOpportunity:
        return Icons.savings_rounded;
      case InsightKind.trendSpike:
        return Icons.trending_up_rounded;
      case InsightKind.trendDrop:
        return Icons.trending_down_rounded;
      case InsightKind.subscriptionAudit:
        return Icons.autorenew_rounded;
      case InsightKind.monthEndProjection:
        return Icons.event_rounded;
      case InsightKind.savingsTarget:
        return Icons.flag_rounded;
      case InsightKind.personality:
        return Icons.psychology_rounded;
      case InsightKind.budgetOverrun:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = insight.categoryId != null
        ? Categories.byId(insight.categoryId!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        boxShadow: AppTheme.cardShadow,
        border: Border(left: BorderSide(color: _accent, width: 4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (insight.potentialSaving > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '↓ ${Formatters.compactMoney(insight.potentialSaving)}',
                          style: const TextStyle(
                            color: AppColors.income,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (cat != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(cat.icon, size: 14, color: cat.color),
                      const SizedBox(width: 4),
                      Text(
                        cat.name,
                        style: TextStyle(
                          color: cat.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Teaser card shown to free users for the remaining, Pro-only insights.
class _LockedInsights extends StatelessWidget {
  const _LockedInsights({required this.count, required this.onUpgrade});

  final int count;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded,
              color: AppColors.accentRed, size: 30),
          const SizedBox(height: 10),
          Text(
            '$count more insight${count == 1 ? '' : 's'} with Pro',
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          const Text(
            'Unlock every savings tip, trend and subscription alert.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onUpgrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
            child: const Text('Upgrade to Pro'),
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
            Icon(Icons.auto_awesome_rounded,
                size: 44, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Your money insights will appear here.\nAdd a few transactions '
              'and Spendly will start coaching you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
