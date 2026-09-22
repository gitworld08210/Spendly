import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Profile / settings. Central place to enable automatic SMS capture
/// (the app's core), and see how PaisaTrack protects privacy.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _autoCapture = false;
  bool _busy = false;

  Future<void> _toggleAutoCapture(bool value) async {
    if (!value) {
      setState(() => _autoCapture = false);
      return;
    }
    setState(() => _busy = true);
    final granted = await SmsService.instance.requestPermission();
    if (granted) {
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission denied')),
      );
    }
    if (mounted) {
      setState(() {
        _autoCapture = granted;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MockData.demoName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'PaisaTrack account',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
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
        ],
      ),
    );
  }
}
