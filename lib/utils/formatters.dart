import 'package:intl/intl.dart';

/// Formatting helpers used across the UI.
class Formatters {
  Formatters._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compact =
      NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

  /// Full currency, e.g. ₹5,480.00
  static String money(double value) => _inr.format(value);

  /// Signed currency, e.g. -₹145.00 / +₹1,200.00
  static String signedMoney(double value) {
    final sign = value < 0 ? '-' : '+';
    return '$sign${_inr.format(value.abs())}';
  }

  /// Compact currency for tight spaces, e.g. ₹5.4K
  static String compactMoney(double value) => _compact.format(value);

  /// e.g. 18 Sep, 2021
  static String date(DateTime dt) => DateFormat('d MMM, yyyy').format(dt);

  /// e.g. 18 Sep · 2:30 PM
  static String dateTime(DateTime dt) =>
      DateFormat('d MMM · h:mm a').format(dt);
}
