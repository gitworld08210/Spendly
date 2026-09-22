import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of the user's engagement streak.
@immutable
class StreakState {
  const StreakState({required this.current, required this.best});
  final int current;
  final int best;
}

/// Tracks a daily "open the app" streak (like Duolingo) to build a habit.
///
/// The date math is pure and testable via [computeNext]. Persistence lives in
/// SharedPreferences.
class StreakService extends ChangeNotifier {
  StreakService._();
  static final StreakService instance = StreakService._();

  static const _currentKey = 'streak_current';
  static const _bestKey = 'streak_best';
  static const _lastDayKey = 'streak_last_day'; // yyyy-mm-dd

  StreakState _state = const StreakState(current: 0, best: 0);
  StreakState get state => _state;

  /// Call once when the app becomes active. Updates the streak based on the
  /// last recorded day vs today.
  Future<void> recordAppOpen([DateTime? now]) async {
    final today = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_currentKey) ?? 0;
      final best = prefs.getInt(_bestKey) ?? 0;
      final lastDayStr = prefs.getString(_lastDayKey);
      final lastDay = lastDayStr == null ? null : DateTime.tryParse(lastDayStr);

      final result = computeNext(
        lastDay: lastDay,
        current: current,
        best: best,
        today: today,
      );

      if (result.changed) {
        await prefs.setInt(_currentKey, result.state.current);
        await prefs.setInt(_bestKey, result.state.best);
        await prefs.setString(_lastDayKey, _dayKey(today));
      }
      _state = result.state;
      notifyListeners();
    } catch (e) {
      debugPrint('StreakService.recordAppOpen failed: $e');
    }
  }

  /// Pure streak transition. Exposed for unit testing.
  ///   - same day  -> unchanged
  ///   - yesterday -> current + 1
  ///   - older/none -> reset to 1
  static ({StreakState state, bool changed}) computeNext({
    required DateTime? lastDay,
    required int current,
    required int best,
    required DateTime today,
  }) {
    final t = DateTime(today.year, today.month, today.day);

    if (lastDay != null) {
      final l = DateTime(lastDay.year, lastDay.month, lastDay.day);
      final diff = t.difference(l).inDays;
      if (diff == 0) {
        // Already counted today.
        return (state: StreakState(current: current, best: best), changed: false);
      }
      if (diff == 1) {
        final next = current + 1;
        return (
          state: StreakState(current: next, best: next > best ? next : best),
          changed: true,
        );
      }
    }
    // No record, or a gap — start a fresh streak at 1.
    return (
      state: StreakState(current: 1, best: best < 1 ? 1 : best),
      changed: true,
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
