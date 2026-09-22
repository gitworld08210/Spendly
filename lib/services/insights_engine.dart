import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/insight.dart';
import '../models/transaction.dart';
import 'recurring_detector.dart';

/// Analyzes a user's transactions (and budgets) to produce personalized,
/// actionable insights — savings opportunities, spending trends, a subscription
/// audit, a month-end projection, a realistic savings target, and a spending
/// "personality".
///
/// Pure functions only (no I/O), so the whole thing is deterministic and
/// unit-testable. Later, a real-AI layer can enrich these with natural
/// language, but the numbers/logic live here.
class InsightsEngine {
  InsightsEngine._();

  /// Generate the full set of insights, sorted most-important first.
  static List<Insight> analyze(
    List<Transaction> transactions, {
    List<Budget> budgets = const [],
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final insights = <Insight>[];

    insights.addAll(_savingsOpportunities(transactions, ref));
    insights.addAll(_trendChanges(transactions, ref));
    final subInsight = _subscriptionAudit(transactions);
    if (subInsight != null) insights.add(subInsight);
    final projection = _monthEndProjection(transactions, ref);
    if (projection != null) insights.add(projection);
    final target = _savingsTarget(transactions, ref);
    if (target != null) insights.add(target);
    insights.addAll(_budgetOverruns(transactions, budgets, ref));
    final personality = _personality(transactions, ref);
    if (personality != null) insights.add(personality);

    insights.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return b.potentialSaving.compareTo(a.potentialSaving);
    });
    return insights;
  }

  /// Total estimated ₹/month the user could save across all opportunities.
  static double totalPotentialSaving(List<Insight> insights) =>
      insights.fold(0.0, (s, i) => s + i.potentialSaving);

  // --- 1. Savings opportunities: category above its own 3-month average -----

  static List<Insight> _savingsOpportunities(
      List<Transaction> txns, DateTime ref) {
    final out = <Insight>[];
    final thisMonth = _monthRange(ref, 0);
    final prev3 = [
      _monthRange(ref, 1),
      _monthRange(ref, 2),
      _monthRange(ref, 3),
    ];

    for (final cat in Categories.all) {
      if (cat.id == 'income') continue;
      final current = _spent(txns, cat.id, thisMonth.$1, thisMonth.$2);
      if (current <= 0) continue;

      final past = prev3
          .map((r) => _spent(txns, cat.id, r.$1, r.$2))
          .where((v) => v > 0)
          .toList();
      if (past.isEmpty) continue;
      final avg = past.reduce((a, b) => a + b) / past.length;
      if (avg <= 0) continue;

      // Spending notably above the personal average → savings opportunity.
      if (current > avg * 1.25 && current - avg >= 300) {
        final saving = current - avg;
        out.add(Insight(
          kind: InsightKind.savingsOpportunity,
          severity: InsightSeverity.warning,
          title: 'Save on ${cat.name}',
          categoryId: cat.id,
          potentialSaving: saving,
          message:
              'You\'ve spent ₹${_fmt(current)} on ${cat.name} this month — '
              'about ₹${_fmt(saving)} more than your usual ₹${_fmt(avg)}. '
              'Trimming back here could save ~₹${_fmt(saving)}/month.',
        ));
      }
    }
    return out;
  }

  // --- 2. Month-over-month trend changes per category -----------------------

  static List<Insight> _trendChanges(List<Transaction> txns, DateTime ref) {
    final out = <Insight>[];
    final thisMonth = _monthRange(ref, 0);
    final lastMonth = _monthRange(ref, 1);

    for (final cat in Categories.all) {
      if (cat.id == 'income') continue;
      final cur = _spent(txns, cat.id, thisMonth.$1, thisMonth.$2);
      final prev = _spent(txns, cat.id, lastMonth.$1, lastMonth.$2);
      if (prev < 500 || cur <= 0) continue;

      final change = (cur - prev) / prev;
      if (change >= 0.30) {
        out.add(Insight(
          kind: InsightKind.trendSpike,
          severity: InsightSeverity.info,
          title: '${cat.name} is up ${(change * 100).round()}%',
          categoryId: cat.id,
          message:
              '${cat.name} spending rose from ₹${_fmt(prev)} last month to '
              '₹${_fmt(cur)} this month. Worth a look.',
        ));
      } else if (change <= -0.30) {
        out.add(Insight(
          kind: InsightKind.trendDrop,
          severity: InsightSeverity.positive,
          title: '${cat.name} down ${(change.abs() * 100).round()}%',
          categoryId: cat.id,
          message:
              'Nice — ${cat.name} dropped from ₹${_fmt(prev)} to '
              '₹${_fmt(cur)} this month. Keep it up!',
        ));
      }
    }
    return out;
  }

  // --- 3. Subscription audit -----------------------------------------------

  static Insight? _subscriptionAudit(List<Transaction> txns) {
    final subs = RecurringDetector.detect(txns);
    if (subs.length < 2) return null;
    final monthly = RecurringDetector.monthlyCommitment(subs);

    // If multiple subscriptions land in the same category, suggest trimming.
    final byCat = <String, int>{};
    for (final s in subs) {
      byCat.update(s.categoryId, (v) => v + 1, ifAbsent: () => 1);
    }
    final overlap = byCat.entries.where((e) => e.value >= 2).toList();

    if (overlap.isNotEmpty) {
      final cat = Categories.byId(overlap.first.key);
      // Rough saving: the cheapest sub in that category.
      final inCat = subs.where((s) => s.categoryId == cat.id).toList()
        ..sort((a, b) => a.typicalAmount.compareTo(b.typicalAmount));
      final saving = inCat.first.typicalAmount;
      return Insight(
        kind: InsightKind.subscriptionAudit,
        severity: InsightSeverity.warning,
        title: 'Overlapping ${cat.name} subscriptions',
        categoryId: cat.id,
        potentialSaving: saving,
        message:
            'You have ${overlap.first.value} recurring ${cat.name} payments '
            '(₹${_fmt(monthly)}/month total across all subscriptions). '
            'Dropping one could save ~₹${_fmt(saving)}/month.',
      );
    }

    return Insight(
      kind: InsightKind.subscriptionAudit,
      severity: InsightSeverity.info,
      title: '${subs.length} recurring payments',
      message:
          'Your subscriptions & bills add up to about ₹${_fmt(monthly)}/month. '
          'Review them to make sure you still use each one.',
    );
  }

  // --- 4. Month-end projection ---------------------------------------------

  static Insight? _monthEndProjection(List<Transaction> txns, DateTime ref) {
    final (start, _) = _monthRange(ref, 0);
    final daysElapsed = ref.difference(start).inDays + 1;
    if (daysElapsed < 3) return null; // too early to project

    final spentSoFar = _spentAll(txns, start, ref);
    if (spentSoFar <= 0) return null;

    final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
    final projected = spentSoFar / daysElapsed * daysInMonth;

    // Compare to last month's total.
    final last = _monthRange(ref, 1);
    final lastTotal = _spentAll(txns, last.$1, last.$2);

    final higher = lastTotal > 0 && projected > lastTotal * 1.1;
    return Insight(
      kind: InsightKind.monthEndProjection,
      severity: higher ? InsightSeverity.warning : InsightSeverity.info,
      title: 'On track for ₹${_fmt(projected)} this month',
      message: lastTotal > 0
          ? 'At your current pace you\'ll spend about ₹${_fmt(projected)} by '
              'month-end — ${higher ? 'more' : 'in line with'} than last '
              'month\'s ₹${_fmt(lastTotal)}.'
          : 'At your current pace you\'ll spend about ₹${_fmt(projected)} by '
              'month-end.',
    );
  }

  // --- 5. Realistic savings target -----------------------------------------

  static Insight? _savingsTarget(List<Transaction> txns, DateTime ref) {
    // Use last full month's discretionary spend (food/shopping/entertainment).
    final last = _monthRange(ref, 1);
    const discretionary = ['food', 'shopping', 'entertainment'];
    double disc = 0;
    for (final id in discretionary) {
      disc += _spent(txns, id, last.$1, last.$2);
    }
    if (disc < 1000) return null;

    // Suggest trimming ~15% of discretionary spend.
    final target = (disc * 0.15).roundToDouble();
    return Insight(
      kind: InsightKind.savingsTarget,
      severity: InsightSeverity.positive,
      title: 'Save ₹${_fmt(target)}/month',
      potentialSaving: target,
      message:
          'Based on your food, shopping and entertainment spend, cutting back '
          'just 15% could realistically save you ₹${_fmt(target)} every month.',
    );
  }

  // --- 6. Budget overruns ---------------------------------------------------

  static List<Insight> _budgetOverruns(
      List<Transaction> txns, List<Budget> budgets, DateTime ref) {
    final out = <Insight>[];
    final (start, end) = _monthRange(ref, 0);
    for (final b in budgets) {
      final spent = _spent(txns, b.categoryId, start, end);
      if (b.monthlyLimit <= 0) continue;
      if (spent > b.monthlyLimit) {
        out.add(Insight(
          kind: InsightKind.budgetOverrun,
          severity: InsightSeverity.critical,
          title: '${b.category.name} budget exceeded',
          categoryId: b.categoryId,
          message:
              'You\'ve spent ₹${_fmt(spent)} against your ₹${_fmt(b.monthlyLimit)} '
              '${b.category.name} budget — over by ₹${_fmt(spent - b.monthlyLimit)}.',
        ));
      }
    }
    return out;
  }

  // --- 7. Spending personality ---------------------------------------------

  static Insight? _personality(List<Transaction> txns, DateTime ref) {
    final start = _monthRange(ref, 2).$1; // last ~3 months
    final debits =
        txns.where((t) => !t.isCredit && !t.date.isBefore(start)).toList();
    if (debits.length < 5) return null;

    // Weekend vs weekday spend.
    double weekend = 0, weekday = 0;
    final byCat = <String, double>{};
    for (final t in debits) {
      if (t.date.weekday == DateTime.saturday ||
          t.date.weekday == DateTime.sunday) {
        weekend += t.amount;
      } else {
        weekday += t.amount;
      }
      byCat.update(t.categoryId, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }

    final topCat = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = Categories.byId(topCat.first.key);

    String label;
    String msg;
    // Weekend days are ~2/7 of the week; flag if weekend share is high.
    if (weekend > weekday * 0.6) {
      label = 'Weekend Spender';
      msg = 'A big chunk of your spending happens on weekends. Planning '
          'weekend outings ahead can keep it in check.';
    } else if (top.id == 'food') {
      label = 'Foodie';
      msg = 'Food & dining is your top spending category. Cooking a couple '
          'more meals at home each week adds up fast.';
    } else if (top.id == 'shopping') {
      label = 'Shopper';
      msg = 'Shopping leads your spending. A 24-hour "cool-off" before big '
          'buys can curb impulse purchases.';
    } else {
      label = 'Balanced Spender';
      msg = 'Your spending is fairly spread out — nice and balanced. '
          'Your top category is ${top.name}.';
    }

    return Insight(
      kind: InsightKind.personality,
      severity: InsightSeverity.info,
      title: 'You\'re a $label',
      categoryId: top.id,
      message: msg,
    );
  }

  // --- helpers --------------------------------------------------------------

  /// (start, endExclusive) for the month [monthsAgo] before [ref].
  static (DateTime, DateTime) _monthRange(DateTime ref, int monthsAgo) {
    final start = DateTime(ref.year, ref.month - monthsAgo);
    final end = DateTime(ref.year, ref.month - monthsAgo + 1);
    return (start, end);
  }

  static double _spent(
      List<Transaction> txns, String categoryId, DateTime from, DateTime to) {
    double total = 0;
    for (final t in txns) {
      if (t.isCredit || t.categoryId != categoryId) continue;
      if (t.date.isBefore(from) || !t.date.isBefore(to)) continue;
      total += t.amount;
    }
    return total;
  }

  static double _spentAll(List<Transaction> txns, DateTime from, DateTime to) {
    double total = 0;
    for (final t in txns) {
      if (t.isCredit) continue;
      if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
      total += t.amount;
    }
    return total;
  }

  static final NumberFormat _numFmt = NumberFormat.decimalPattern('en_IN');

  /// Indian-style grouped number without decimals, e.g. 12,500.
  static String _fmt(double v) => _numFmt.format(v.round());
}
