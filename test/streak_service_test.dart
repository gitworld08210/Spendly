import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/services/streak_service.dart';

void main() {
  group('StreakService.computeNext', () {
    test('first ever open starts streak at 1', () {
      final r = StreakService.computeNext(
        lastDay: null,
        current: 0,
        best: 0,
        today: DateTime(2026, 6, 1),
      );
      expect(r.changed, isTrue);
      expect(r.state.current, 1);
      expect(r.state.best, 1);
    });

    test('same-day open does not change the streak', () {
      final r = StreakService.computeNext(
        lastDay: DateTime(2026, 6, 1, 9),
        current: 3,
        best: 5,
        today: DateTime(2026, 6, 1, 21),
      );
      expect(r.changed, isFalse);
      expect(r.state.current, 3);
      expect(r.state.best, 5);
    });

    test('consecutive day increments and updates best', () {
      final r = StreakService.computeNext(
        lastDay: DateTime(2026, 6, 1),
        current: 5,
        best: 5,
        today: DateTime(2026, 6, 2),
      );
      expect(r.changed, isTrue);
      expect(r.state.current, 6);
      expect(r.state.best, 6);
    });

    test('gap resets streak to 1 but keeps best', () {
      final r = StreakService.computeNext(
        lastDay: DateTime(2026, 6, 1),
        current: 9,
        best: 9,
        today: DateTime(2026, 6, 5),
      );
      expect(r.changed, isTrue);
      expect(r.state.current, 1);
      expect(r.state.best, 9);
    });
  });
}
