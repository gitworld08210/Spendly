import 'package:flutter/material.dart';

import '../screens/paywall_screen.dart';
import '../services/pro_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Opens the paywall. Returns true if the user became Pro.
Future<bool> showPaywall(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PaywallScreen(), fullscreenDialog: true),
  );
  return result ?? false;
}

/// A small "PRO" pill used to mark premium features.
class ProPill extends StatelessWidget {
  const ProPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Wraps [child] and, when the user is not Pro, overlays a soft lock with an
/// "Upgrade" CTA. When Pro, shows [child] directly. Rebuilds on Pro changes.
class ProGate extends StatelessWidget {
  const ProGate({
    super.key,
    required this.child,
    this.teaserHeight = 180,
    this.title = 'A Pro feature',
    this.subtitle = 'Upgrade to unlock',
  });

  final Widget child;
  final double teaserHeight;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProService.instance,
      builder: (context, _) {
        if (ProService.instance.isPro) return child;
        return Container(
          height: teaserHeight,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  color: AppColors.accentRed, size: 30),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => showPaywall(context),
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
      },
    );
  }
}
