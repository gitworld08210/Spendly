import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper over SharedPreferences for lightweight app settings.
class AppPrefs {
  AppPrefs._();

  static const _smsCutoffKey = 'sms_cutoff_millis';
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _referralCodeKey = 'referral_code';

  /// Returns a stable, human-friendly referral code for this device/user,
  /// generating and persisting one on first use (e.g. "SPND7K2Q").
  static Future<String> referralCode([String? seed]) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_referralCodeKey);
    if (existing != null) return existing;

    final basis = (seed ?? DateTime.now().microsecondsSinceEpoch.toString());
    // Deterministic, ambiguous-char-free 4-char suffix.
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var hash = 0;
    for (final code in basis.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final buf = StringBuffer('SPND');
    for (var i = 0; i < 4; i++) {
      buf.write(alphabet[hash % alphabet.length]);
      hash ~/= alphabet.length;
    }
    final code = buf.toString();
    await prefs.setString(_referralCodeKey, code);
    return code;
  }

  /// Whether the user has already completed the one-time intro flow.
  static Future<bool> onboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  /// Marks the intro flow as completed so it isn't shown again.
  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

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
