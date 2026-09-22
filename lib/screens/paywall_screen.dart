import 'package:flutter/material.dart';

import '../services/pro_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Spendly Pro upgrade screen. Presents the value + price and a CTA.
///
/// Payment is intentionally not wired yet — when a gateway (e.g. Razorpay) is
/// added, its success callback calls [ProService.activatePro]. Until then the
/// CTA activates Pro directly so the gated features can be demoed/tested.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  static const _perks = <(IconData, String, String)>[
    (Icons.auto_awesome_rounded, 'Unlimited AI insights',
        'Deep, personalized coaching on where to save'),
    (Icons.picture_as_pdf_rounded, 'Reports & export',
        'Monthly PDF/Excel reports for taxes & records'),
    (Icons.account_balance_rounded, 'Multiple accounts',
        'Track every bank & wallet in one place'),
    (Icons.autorenew_rounded, 'Subscription radar',
        'Never miss a recurring charge again'),
    (Icons.notifications_active_rounded, 'Smart alerts',
        'Real-time nudges before you overspend'),
  ];

  Future<void> _upgrade() async {
    setState(() => _busy = true);
    // TODO(payment): replace with gateway checkout; on success -> activatePro.
    await ProService.instance.activatePro();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Welcome to Spendly Pro! 🎉')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Spendly Pro',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Get the full money coach and take control of your '
                    'finances.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ..._perks.map((p) => _PerkRow(
                        icon: p.$1,
                        title: p.$2,
                        subtitle: p.$3,
                      )),
                ],
              ),
            ),
            _PriceBar(busy: _busy, onUpgrade: _upgrade),
          ],
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accentRed, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBar extends StatelessWidget {
  const _PriceBar({required this.busy, required this.onUpgrade});

  final bool busy;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹99',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900)),
              Text(' / month',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Cancel anytime',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Upgrade to Pro',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
