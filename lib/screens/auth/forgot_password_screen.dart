import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/brand_header.dart';

/// Password reset in three inline steps:
///   1. Enter email -> Supabase emails a 6-digit recovery code.
///   2. Enter the code -> verified (session elevated).
///   3. Set a new password -> done, back to login.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, newPassword }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      showAuthError(context, 'Enter a valid email');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) setState(() => _step = _Step.code);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      showAuthError(context, 'Enter the 6-digit code');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyRecoveryOtp(
        email: _emailCtrl.text.trim(),
        code: code,
      );
      if (mounted) setState(() => _step = _Step.newPassword);
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _passwordCtrl.text;
    if (pw.length < 6) {
      showAuthError(context, 'Password must be 6+ characters');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.updatePassword(pw);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. Please log in.')),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  switch (_step) {
                    _Step.email => 'Reset your password',
                    _Step.code => 'Enter the code',
                    _Step.newPassword => 'Set a new password',
                  },
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_step == _Step.email) ..._emailStep(),
              if (_step == _Step.code) ..._codeStep(),
              if (_step == _Step.newPassword) ..._passwordStep(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStep() => [
        AuthField(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Send reset code',
          loading: _loading,
          onPressed: _sendCode,
        ),
      ];

  List<Widget> _codeStep() => [
        Text(
          'We emailed a 6-digit code to ${_emailCtrl.text.trim()}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
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
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Verify code',
          loading: _loading,
          onPressed: _verifyCode,
        ),
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text('Resend code',
              style: TextStyle(color: AppColors.accentRed)),
        ),
      ];

  List<Widget> _passwordStep() => [
        AuthField(
          controller: _passwordCtrl,
          label: 'New password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          suffix: IconButton(
            icon: Icon(_obscure
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Update password',
          loading: _loading,
          onPressed: _setNewPassword,
        ),
      ];
}
