import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// The signature near-black "wallet" card from the reference design:
/// balance, a gradient progress strip, masked card number and a
/// mastercard-style glyph.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.balance,
    required this.last4,
    this.spentRatio = 0.6,
    this.onMore,
  });

  final double balance;
  final String last4;

  /// 0..1 — how far along the gradient strip fills (share of budget used).
  final double spentRatio;
  final VoidCallback? onMore;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.money(balance),
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Balance',
                    style: TextStyle(
                      color: AppColors.textOnDarkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz, color: AppColors.textOnDark),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Gradient progress strip.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 6, color: AppColors.inkSoft),
                FractionallySizedBox(
                  widthFactor: spentRatio.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: AppColors.accentGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '••••  ••••  $last4',
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 15,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const _MastercardGlyph(),
            ],
          ),
        ],
      ),
    );
  }
}

class _MastercardGlyph extends StatelessWidget {
  const _MastercardGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 24,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            child: CircleAvatar(radius: 12, backgroundColor: AppColors.accentRed),
          ),
          Positioned(
            left: 14,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.accentOrange.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
