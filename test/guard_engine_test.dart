import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/guard_alert.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/services/guard_engine.dart';

Transaction _t(String title, double amount, DateTime date, String cat,
    {TxnType type = TxnType.debit, String? id, String? raw}) {
  return Transaction(
    id: id ?? '$title-${date.microsecondsSinceEpoch}-$amount',
    title: title,
    amount: amount,
    type: type,
    categoryId: cat,
    date: date,
    rawSms: raw,
  );
}

void main() {
  final now = DateTime(2026, 6, 15);
  DateTime day(int monthsAgo, int d, [int h = 10]) =>
      DateTime(2026, 6 - monthsAgo, d, h);

  group('GuardEngine', () {
    test('detects a duplicate/double charge within 48h', () {
      final txns = [
        _t('Amazon', 1499, day(0, 10, 9), 'shopping', id: 'a'),
        _t('Amazon', 1499, day(0, 10, 12), 'shopping', id: 'b'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      final dup =
          s.alerts.where((a) => a.kind == GuardKind.duplicateCharge).toList();
      expect(dup, isNotEmpty);
      expect(dup.first.severity, GuardSeverity.high);
      expect(dup.first.amountAtRisk, 1499);
    });

    test('does not flag same amount far apart as duplicate', () {
      final txns = [
        _t('Amazon', 1499, day(0, 1), 'shopping'),
        _t('Amazon', 1499, day(0, 20), 'shopping'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(
        s.alerts.any((a) => a.kind == GuardKind.duplicateCharge),
        isFalse,
      );
    });

    test('flags a hidden bank charge', () {
      final txns = [
        _t('SMS Alert Charge', 23.6, day(0, 5), 'bills',
            raw: 'Rs.23.60 debited SMS ALERT CHARGES'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(
        s.alerts.any((a) => a.kind == GuardKind.hiddenCharge),
        isTrue,
      );
    });

    test('flags a category spike', () {
      final txns = [
        _t('Electricity', 1000, day(1, 5), 'bills'),
        _t('Electricity', 1000, day(2, 5), 'bills'),
        _t('Electricity', 1000, day(3, 5), 'bills'),
        _t('Electricity', 3000, day(0, 5), 'bills'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(s.alerts.any((a) => a.kind == GuardKind.spike), isTrue);
    });

    test('flags an unusually large payment given history', () {
      final txns = <Transaction>[
        for (var i = 0; i < 10; i++)
          _t('Snack', 200, day(1, 1 + i), 'food'),
        _t('Unknown Merchant', 60000, day(0, 3), 'other', id: 'big'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(
        s.alerts.any((a) => a.kind == GuardKind.unusualTransaction),
        isTrue,
      );
    });

    test('flags recurring subscriptions for review with a saving', () {
      final txns = [
        _t('Netflix', 199, day(2, 3), 'entertainment'),
        _t('Netflix', 199, day(1, 3), 'entertainment'),
        _t('Netflix', 199, day(0, 3), 'entertainment'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      final sub = s.alerts
          .where((a) => a.kind == GuardKind.unusedSubscription)
          .toList();
      expect(sub, isNotEmpty);
      expect(sub.first.potentialSaving, greaterThan(0));
    });

    test('clean history produces no alerts and isProtected is true', () {
      final txns = [
        _t('Coffee', 120, day(0, 2), 'food'),
        _t('Bus', 40, day(0, 4), 'travel'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(s.isProtected, isTrue);
      expect(s.alerts, isEmpty);
    });

    test('summary totals aggregate risk and savings', () {
      final txns = [
        _t('Amazon', 1499, day(0, 10, 9), 'shopping', id: 'a'),
        _t('Amazon', 1499, day(0, 10, 12), 'shopping', id: 'b'),
      ];
      final s = GuardEngine.scan(txns, now: now);
      expect(s.totalAtRisk, greaterThan(0));
    });
  });
}
