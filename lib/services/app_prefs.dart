import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper over SharedPreferences for lightweight app settings.
class AppPrefs {
  AppPrefs._();

  static const _smsCutoffKey = 'sms_cutoff_millis';

  /// The moment SMS auto-capture was first enabled. Only SMS received at or
  /// after this instant are imported — older inbox messages (from before the
  /// user started using Spendly) are ignored.
  static Future<DateTime?> smsCutoff() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_smsCutoffKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Records [when] (default: now) as the SMS cutoff, but only the first time —
  /// subsequent calls keep the original cutoff so re-toggling doesn't suddenly
  /// pull in older messages.
  static Future<DateTime> ensureSmsCutoff([DateTime? when]) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt(_smsCutoffKey);
    if (existing != null) {
      return DateTime.fromMillisecondsSinceEpoch(existing);
    }
    final cutoff = when ?? DateTime.now();
    await prefs.setInt(_smsCutoffKey, cutoff.millisecondsSinceEpoch);
    return cutoff;
  }
}
