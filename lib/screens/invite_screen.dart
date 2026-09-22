import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_prefs.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';

/// "Invite friends" screen — a simple, share-driven growth loop. Shows a
/// personal referral code and a one-tap share of an invite message.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String? _code;

  static const _playUrl =
      'https://play.google.com/store/apps/details?id=com.paisatrack.paisatrack';

  @override
  void initState() {
    super.initState();
    final seed = AuthService.instance.currentUser?.id;
    AppPrefs.referralCode(seed).then((c) {
      if (mounted) setState(() => _code = c);
    });
  }

  String get _inviteText =>
      'I track my spends automatically with Spendly 💸 — it reads bank/UPI '
      'SMS and shows exactly where my money goes. Try it'
      '${_code != null ? ' with my code $_code' : ''}:\n$_playUrl';

  Future<void> _share() => Share.share(_inviteText, subject: 'Try Spendly');

  void _copy() {
    Clipboard.setData(ClipboardData(text: _code ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: 8),
          const BrandHeader(showTagline: false),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Love Spendly? Share it!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Help your friends take control of their money too. The more people '
            'track smart, the better.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Referral code card.
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                const Text('Your referral code',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  _code ?? '••••••••',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _code == null ? null : _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Invite friends'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
