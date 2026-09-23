import 'package:flutter/material.dart';

import '../models/guard_alert.dart';
import '../repositories/transaction_repository.dart';
import '../services/guard_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Paisa Guard — Spendly's money-protection screen. Surfaces double charges,
/// bank fees, spikes, unusual payments, and subscriptions to review, with a
/// clear "money at risk / you could save" header.
class PaisaGuardScreen extends StatefulWidget {
  const PaisaGuardScreen({super.key});

  @override
  State<PaisaGuardScreen> createState() => _PaisaGuardScreenState();
}

class _PaisaGuardScreenState extends State<PaisaGuardScreen> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Paisa Guard')),
      body: AnimatedBuilder(
        animation: repo,
        builder: (context, _) {
          final summary = GuardEngine.scan(repo.all);
          final alerts =
              summary.alerts.where((a) => !_dismissed.contains(a.id)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
            children: [
              _GuardHeader(
                protected: alerts.isEmpty,
                atRisk: alerts.fold(0.0, (s, a) => s + a.amountAtRisk),
                saving: alerts.fold(0.0, (s, a) => s + a.potentialSaving),
                count: alerts.length,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (alerts.isEmpty)
                const _AllClear()
              else
                ...alerts.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlertCard(
                        alert: a,
                        onMarkSafe: () =>
                            setState(() => _dismissed.add(a.id)),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _GuardHeader extends StatelessWidget {
  const _GuardHeader({
    required this.protected,
    required this.atRisk,
    required this.saving,
    required this.count,
  });

  final bool protected;
  final double atRisk;
  final double saving;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: protected
                  ? const LinearGradient(
                      colors: [Color(0xFF27C093), Color(0xFF12784E)])
                  : AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              protected
                  ? Icons.verified_user_rounded
                  : Icons.shield_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            protected ? "You're protected" : '$count thing${count == 1 ? '' : 's'} to review',
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            protected
                ? 'Paisa Guard scanned your money and found no issues.'
                : 'Paisa Guard spotted things worth a look.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
          ),
          if (!protected) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (atRisk > 0)
                  Expanded(
                    child: _Metric(
                      label: 'At risk',
                      value: Formatters.compactMoney(atRisk),
                      color: AppColors.accentRed,
                    ),
                  ),
                if (saving > 0)
                  Expanded(
                    child: _Metric(
                      label: 'Could save',
                      value: '${Formatters.compactMoney(saving)}/mo',
                      color: AppColors.income,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textOnDarkMuted, fontSize: 12)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onMarkSafe});

  final GuardAlert alert;
  final VoidCallback onMarkSafe;

  Color get _accent {
    switch (alert.severity) {
      case GuardSeverity.high:
        return AppColors.accentRed;
      case GuardSeverity.medium:
        return AppColors.accentOrange;
      case GuardSeverity.low:
        return const Color(0xFF2FB1F0);
    }
  }

  IconData get _icon {
    switch (alert.kind) {
      case GuardKind.duplicateCharge:
        return Icons.copy_all_rounded;
      case GuardKind.hiddenCharge:
        return Icons.account_balance_rounded;
      case GuardKind.unusedSubscription:
        return Icons.autorenew_rounded;
      case GuardKind.spike:
        return Icons.trending_up_rounded;
      case GuardKind.unusualTransaction:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        boxShadow: AppTheme.cardShadow,
        border: Border(left: BorderSide(color: _accent, width: 4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(alert.message,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMarkSafe,
              child: Text(
                alert.kind == GuardKind.unusedSubscription
                    ? 'Dismiss'
                    : 'Mark as safe',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.income, size: 44),
          SizedBox(height: 12),
          Text(
            'All clear! No double charges, hidden fees or unusual payments '
            'found. Paisa Guard keeps watching.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
