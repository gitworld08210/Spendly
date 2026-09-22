import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A rounded, filled text field used across the auth screens.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffix,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5),
        ),
      ),
    );
  }
}

/// The primary dark pill button (with a loading state).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Shows a red snackbar with an error message.
void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
