import 'package:flutter/material.dart';

import '../repositories/transaction_repository.dart';
import '../services/guard_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A compact Paisa Guard status banner for the dashboard. Shows a shield with
/// the count of things to review, or a green "protected" pill. Tapping opens
/// the full Guard screen.
class GuardBanner extends StatelessWidget {
  const GuardBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final summary = GuardEngine.scan(repo.all);
        final protected = summary.isProtected;
        final color = protected ? AppColors.income : AppColors.accentRed;

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
                      protected
                          ? Icons.verified_user_rounded
                          : Icons.shield_rounded,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            protected
                                ? 'Paisa Guard: you\'re protected'
                                : 'Paisa Guard: ${summary.count} to review',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            protected
                                ? 'No double charges or hidden fees found'
                                : 'Tap to see what needs your attention',
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
