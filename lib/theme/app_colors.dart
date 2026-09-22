import 'package:flutter/material.dart';

/// Central color palette for PaisaTrack.
///
/// Derived from the reference designs: a clean light background with soft
/// white cards, a near-black "wallet" card, and a warm orange→red gradient
/// used as the primary accent (the card strip / active states).
class AppColors {
  AppColors._();

  // Brand accent — the orange→red gradient from the wallet card strip.
  static const Color accentOrange = Color(0xFFFF8A34);
  static const Color accentRed = Color(0xFFF5432C);
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentOrange, accentRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Surfaces (light theme — the dominant look in the screenshots).
  static const Color background = Color(0xFFF4F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0F1F4);

  // Dark "wallet" card + dark surfaces.
  static const Color ink = Color(0xFF111214);
  static const Color inkSoft = Color(0xFF1C1D21);

  // Text.
  static const Color textPrimary = Color(0xFF16171A);
  static const Color textSecondary = Color(0xFF8A8D96);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFB4B6BE);

  // Semantic.
  static const Color income = Color(0xFF27C093);
  static const Color incomeSoft = Color(0xFFE7F8F1);
  static const Color expense = Color(0xFFFF8A34);
  static const Color expenseSoft = Color(0xFFFFF2E7);

  static const Color divider = Color(0xFFECEDF0);
  static const Color shadow = Color(0x14000000);
}
