import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/brand_header.dart';

/// Signup step 2: enter the 6-digit code emailed to the user. On success the
/// account is created (by the Edge Function) and the user is signed in.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
  });

  final String email;
  final String password;
  final String name;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      showAuthError(context, 'Enter the 6-digit code.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.verifySignup(
        email: widget.email,
        code: code,
        password: widget.password,
        name: widget.name,
      );
      if (!mounted) return;
      // Signed in — pop back to the root; AuthGate shows the app.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthService.instance.startSignup(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const BrandHeader(showTagline: false),
              const SizedBox(height: 28),
              const Text(
                'Verify your email',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit code sent to\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Verify & create account',
                loading: _loading,
                onPressed: _verify,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(
                  _resending ? 'Sending…' : 'Resend code',
                  style: const TextStyle(
                    color: AppColors.accentRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
