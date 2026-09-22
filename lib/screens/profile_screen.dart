import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'budgets_screen.dart';
import 'recurring_screen.dart';

/// Profile / settings. Central place to enable automatic SMS capture
/// (the app's core), see how Spendly protects privacy, and log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _autoCapture = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncPermissionState();
  }

  Future<void> _syncPermissionState() async {
    final has = await SmsService.instance.hasPermission();
    if (has && mounted) {
      SmsService.instance.startListening();
      setState(() => _autoCapture = true);
    }
  }

  Future<void> _toggleAutoCapture(bool value) async {
    if (!value) {
      setState(() => _autoCapture = false);
      return;
    }
    setState(() => _busy = true);
    final result = await SmsService.instance.requestPermission();

    if (result == SmsPermissionResult.granted) {
      final imported = await SmsService.instance.backfillInbox();
      SmsService.instance.startListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported > 0
                  ? 'Auto-capture on · imported $imported transactions'
                  : 'Auto-capture on · watching for new SMS',
            ),
          ),
        );
      }
    } else if (result == SmsPermissionResult.permanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'SMS permission is blocked. Open Settings to allow it.',
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => SmsService.instance.openSettings(),
            ),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission denied. Tap the toggle to try again.'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _autoCapture = result == SmsPermissionResult.granted;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120),
        children: [
          const Center(
            child: Text(
              'Profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.ink,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AuthService.instance.displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      AuthService.instance.currentUser?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoCapture,
                  onChanged: _busy ? null : _toggleAutoCapture,
                  activeThumbColor: AppColors.accentRed,
                  title: const Text(
                    'Automatic SMS capture',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _busy
                        ? 'Requesting access…'
                        : 'Read bank/UPI alerts and log spends automatically',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  secondary: const Icon(Icons.sms_rounded,
                      color: AppColors.accentRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _NavCard(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budgets',
            subtitle: 'Set monthly limits and get overspend alerts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.autorenew_rounded,
            title: 'Recurring payments',
            subtitle: 'See subscriptions & bills Spendly detected',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.incomeSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_rounded, color: AppColors.income, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy first: your SMS are read and parsed on your '
                    'phone. Only the extracted transaction is synced — never '
                    'the raw message.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout_rounded, color: AppColors.accentRed),
            label: const Text(
              'Log out',
              style: TextStyle(
                color: AppColors.accentRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.accentRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable settings row leading to another screen.
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.accentRed),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
