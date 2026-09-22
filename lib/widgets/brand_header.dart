import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Spendly brand lockup used on auth screens: a rounded gradient tile with a
/// stylized "S" + ₹, the wordmark, and the tagline.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.showTagline = true});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.white,
                  child: Text(
                    '₹',
                    style: TextStyle(
                      color: AppColors.accentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Spendly',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          const Text(
            'Spend smarter. Live better.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ],
    );
  }
}
