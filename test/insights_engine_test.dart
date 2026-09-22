import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/budget.dart';
import 'package:paisatrack/models/insight.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/services/insights_engine.dart';

Transaction _t(String title, double amount, DateTime date, String cat,
    {TxnType type = TxnType.debit}) {
  return Transaction(
    id: '$title-${date.microsecondsSinceEpoch}-$amount',
    title: title,
    amount: amount,
    type: type,
    categoryId: cat,
    date: date,
  );
}

void main() {
  // Fixed "now" so month math is deterministic.
  final now = DateTime(2026, 6, 15);
  DateTime inMonth(int monthsAgo, int day) =>
      DateTime(2026, 6 - monthsAgo, day);

  group('InsightsEngine', () {
    test('flags a savings opportunity when a category spikes vs its average',
        () {
      final txns = <Transaction>[
        // Past 3 months food ~ 2000 each.
        _t('Zomato', 2000, inMonth(1, 10), 'food'),
        _t('Zomato', 2000, inMonth(2, 10), 'food'),
        _t('Zomato', 2000, inMonth(3, 10), 'food'),
        // This month way higher.
        _t('Zomato', 5000, inMonth(0, 10), 'food'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      final saving = insights
          .where((i) => i.kind == InsightKind.savingsOpportunity)
          .toList();
      expect(saving, isNotEmpty);
      expect(saving.first.categoryId, 'food');
      expect(saving.first.potentialSaving, greaterThan(0));
    });

    test('detects month-over-month spike as a trend insight', () {
      final txns = <Transaction>[
        _t('Amazon', 1000, inMonth(1, 5), 'shopping'),
        _t('Amazon', 2000, inMonth(0, 5), 'shopping'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      expect(
        insights.any((i) => i.kind == InsightKind.trendSpike),
        isTrue,
      );
    });

    test('subscription audit fires for overlapping category subscriptions', () {
      final txns = <Transaction>[
        _t('Netflix', 200, inMonth(2, 3), 'entertainment'),
        _t('Netflix', 200, inMonth(1, 3), 'entertainment'),
        _t('Netflix', 200, inMonth(0, 3), 'entertainment'),
        _t('Hotstar', 300, inMonth(2, 8), 'entertainment'),
        _t('Hotstar', 300, inMonth(1, 8), 'entertainment'),
        _t('Hotstar', 300, inMonth(0, 8), 'entertainment'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      final audit = insights
          .where((i) => i.kind == InsightKind.subscriptionAudit)
          .toList();
      expect(audit, isNotEmpty);
      expect(audit.first.potentialSaving, greaterThan(0));
    });

    test('projects month-end spend', () {
      final txns = <Transaction>[
        for (var d = 1; d <= 10; d++) _t('Shop', 500, inMonth(0, d), 'shopping'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      expect(
        insights.any((i) => i.kind == InsightKind.monthEndProjection),
        isTrue,
      );
    });

    test('suggests a realistic savings target from discretionary spend', () {
      final txns = <Transaction>[
        _t('Zomato', 4000, inMonth(1, 5), 'food'),
        _t('Amazon', 3000, inMonth(1, 12), 'shopping'),
        _t('Netflix', 500, inMonth(1, 20), 'entertainment'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      final target =
          insights.where((i) => i.kind == InsightKind.savingsTarget).toList();
      expect(target, isNotEmpty);
      expect(target.first.potentialSaving, greaterThan(0));
    });

    test('critical budget-overrun insight sorts to the top', () {
      final txns = <Transaction>[
        _t('Zomato', 6000, inMonth(0, 5), 'food'),
      ];
      final budgets = [
        const Budget(id: 'b1', categoryId: 'food', monthlyLimit: 3000),
      ];
      final insights =
          InsightsEngine.analyze(txns, budgets: budgets, now: now);
      expect(insights.first.kind, InsightKind.budgetOverrun);
      expect(insights.first.severity, InsightSeverity.critical);
    });

    test('assigns a spending personality with enough history', () {
      final txns = <Transaction>[
        for (var i = 0; i < 6; i++)
          _t('Zomato', 800, inMonth(1, 3 + i), 'food'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      expect(
        insights.any((i) => i.kind == InsightKind.personality),
        isTrue,
      );
    });

    test('empty transactions produce no crash and no insights', () {
      expect(InsightsEngine.analyze(const [], now: now), isEmpty);
    });

    test('totalPotentialSaving sums savings across insights', () {
      final txns = <Transaction>[
        _t('Zomato', 2000, inMonth(1, 10), 'food'),
        _t('Zomato', 2000, inMonth(2, 10), 'food'),
        _t('Zomato', 5000, inMonth(0, 10), 'food'),
      ];
      final insights = InsightsEngine.analyze(txns, now: now);
      expect(InsightsEngine.totalPotentialSaving(insights), greaterThan(0));
    });
  });
}
