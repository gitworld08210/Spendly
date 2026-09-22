import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_header.dart';

/// One-time intro shown before the first login/signup. Explains the value
/// proposition, privacy stance, and how spends get captured.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Called when the user finishes or skips the intro.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      icon: Icons.auto_awesome_rounded,
      title: 'Your money, on autopilot',
      body:
          'Spendly reads your bank & UPI alerts and logs every spend for you — '
          'no manual entry. See exactly where your money goes.',
    ),
    _OnboardPage(
      icon: Icons.savings_rounded,
      title: 'A coach, not just a tracker',
      body:
          'Get personalized tips on where you can save, spot subscriptions '
          'you forgot, and hit realistic monthly savings goals.',
    ),
    _OnboardPage(
      icon: Icons.lock_rounded,
      title: 'Private by design',
      body:
          'Your SMS are read and parsed on your phone. Only the extracted '
          "transaction is synced — never the raw message. Prefer not to grant "
          'SMS access? Just paste a message instead.',
    ),
  ];

  Future<void> _finish() async {
    await AppPrefs.setOnboardingSeen();
    widget.onDone();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 8),
            const BrandHeader(),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accentRed : AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Get started' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 46, color: AppColors.accentRed),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
