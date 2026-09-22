import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Manages the user's "Spendly Pro" entitlement.
///
/// Source of truth is the `profiles.is_pro` column in Supabase, mirrored to a
/// local flag for instant, offline reads. Payment is intentionally decoupled:
/// once a payment gateway (e.g. Razorpay) is wired, its success callback simply
/// calls [activatePro]. Until then, Pro can be toggled for testing.
class ProService extends ChangeNotifier {
  ProService._() {
    _load();
    try {
      if (SupabaseConfig.isConfigured) {
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
          _syncFromServer();
        });
      }
    } catch (_) {
      // Supabase not initialized (tests) — local flag only.
    }
  }

  static final ProService instance = ProService._();

  static const _proKey = 'is_pro';

  /// Growth phase: everything is free for everyone. While this is true, [isPro]
  /// always reports true so no feature is gated — the paywall/entitlement code
  /// stays in place and ready, but nothing blocks users. Flip to false when we
  /// decide to actually charge.
  static const bool _launchAllFree = true;

  bool _isPro = false;

  /// Whether the user has full (Pro) access. During the free-launch phase this
  /// is always true.
  bool get isPro => _launchAllFree || _isPro;

  /// The real, paid entitlement (ignores the free-launch override) — used by
  /// the paywall so it can still show "upgrade" state during testing if needed.
  bool get isPaidPro => _isPro;

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool(_proKey) ?? false;
      notifyListeners();
    } catch (_) {}
    await _syncFromServer();
  }

  /// Reads the authoritative Pro flag from the user's profile row.
  Future<void> _syncFromServer() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      final row = await client
          .from('profiles')
          .select('is_pro')
          .eq('id', user.id)
          .maybeSingle();
      final serverPro = (row?['is_pro'] as bool?) ?? false;
      if (serverPro != _isPro) {
        _isPro = serverPro;
        await _persistLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ProService._syncFromServer failed: $e');
    }
  }

  /// Grants Pro. Called by the payment success callback once wired, or from
  /// the paywall's test button until then. Persists locally + to Supabase.
  Future<void> activatePro() async {
    _isPro = true;
    await _persistLocal();
    notifyListeners();

    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'is_pro': true,
        'pro_since': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ProService.activatePro failed: $e');
    }
  }

  /// Revokes Pro (e.g. subscription lapse / testing).
  Future<void> deactivatePro() async {
    _isPro = false;
    await _persistLocal();
    notifyListeners();

    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client
          .from('profiles')
          .upsert({'id': user.id, 'is_pro': false});
    } catch (e) {
      debugPrint('ProService.deactivatePro failed: $e');
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proKey, _isPro);
    } catch (_) {}
  }
}
