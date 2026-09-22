import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/services/recurring_detector.dart';

Transaction _txn(String title, double amount, DateTime date,
    {TxnType type = TxnType.debit, String cat = 'entertainment'}) {
  return Transaction(
    id: '$title-${date.millisecondsSinceEpoch}',
    title: title,
    amount: amount,
    type: type,
    categoryId: cat,
    date: date,
  );
}

void main() {
  group('RecurringDetector', () {
    test('detects a monthly subscription', () {
      final txns = [
        _txn('Netflix', 199, DateTime(2026, 1, 5)),
        _txn('Netflix', 199, DateTime(2026, 2, 5)),
        _txn('Netflix', 199, DateTime(2026, 3, 5)),
      ];
      final subs = RecurringDetector.detect(txns);
      expect(subs, hasLength(1));
      expect(subs.first.merchant, 'Netflix');
      expect(subs.first.typicalAmount, 199);
      expect(subs.first.occurrences, 3);
      expect(subs.first.cadenceLabel, 'Monthly');
    });

    test('ignores one-off purchases', () {
      final txns = [
        _txn('Amazon', 1500, DateTime(2026, 1, 10), cat: 'shopping'),
        _txn('Zomato', 300, DateTime(2026, 1, 12), cat: 'food'),
      ];
      expect(RecurringDetector.detect(txns), isEmpty);
    });

    test('ignores merchants with wildly varying amounts', () {
      final txns = [
        _txn('Zomato', 200, DateTime(2026, 1, 5), cat: 'food'),
        _txn('Zomato', 900, DateTime(2026, 2, 5), cat: 'food'),
        _txn('Zomato', 150, DateTime(2026, 3, 5), cat: 'food'),
      ];
      expect(RecurringDetector.detect(txns), isEmpty);
    });

    test('ignores credits', () {
      final txns = [
        _txn('Salary', 50000, DateTime(2026, 1, 1), type: TxnType.credit),
        _txn('Salary', 50000, DateTime(2026, 2, 1), type: TxnType.credit),
      ];
      expect(RecurringDetector.detect(txns), isEmpty);
    });

    test('normalizes merchant names with reference numbers', () {
      final txns = [
        _txn('Spotify #12345', 119, DateTime(2026, 1, 8)),
        _txn('Spotify #67890', 119, DateTime(2026, 2, 8)),
      ];
      final subs = RecurringDetector.detect(txns);
      expect(subs, hasLength(1));
      expect(subs.first.occurrences, 2);
    });

    test('nextDate projects roughly one cadence ahead', () {
      final txns = [
        _txn('Rent', 15000, DateTime(2026, 1, 1), cat: 'bills'),
        _txn('Rent', 15000, DateTime(2026, 2, 1), cat: 'bills'),
      ];
      final sub = RecurringDetector.detect(txns).first;
      expect(sub.nextDate.isAfter(DateTime(2026, 2, 20)), isTrue);
    });

    test('monthlyCommitment sums normalized per-month costs', () {
      final txns = [
        _txn('Netflix', 200, DateTime(2026, 1, 5)),
        _txn('Netflix', 200, DateTime(2026, 2, 5)),
        _txn('Spotify', 100, DateTime(2026, 1, 8)),
        _txn('Spotify', 100, DateTime(2026, 2, 8)),
      ];
      final subs = RecurringDetector.detect(txns);
      final total = RecurringDetector.monthlyCommitment(subs);
      // ~300/month combined, allow tolerance for cadence normalization.
      expect(total, greaterThan(250));
      expect(total, lessThan(360));
    });
  });
}
