import '../models/transaction.dart';

/// A detected recurring payment (subscription, rent, EMI, etc.).
class RecurringSubscription {
  const RecurringSubscription({
    required this.merchant,
    required this.categoryId,
    required this.typicalAmount,
    required this.occurrences,
    required this.lastDate,
    required this.averageGapDays,
  });

  final String merchant;
  final String categoryId;
  final double typicalAmount;
  final int occurrences;
  final DateTime lastDate;
  final double averageGapDays;

  /// Best-guess next charge date based on the average cadence.
  DateTime get nextDate =>
      lastDate.add(Duration(days: averageGapDays.round()));

  /// Human label for the cadence.
  String get cadenceLabel {
    if (averageGapDays <= 9) return 'Weekly';
    if (averageGapDays <= 20) return 'Fortnightly';
    if (averageGapDays <= 45) return 'Monthly';
    if (averageGapDays <= 100) return 'Quarterly';
    return 'Yearly';
  }
}

/// Finds recurring payments by looking for the same merchant charged on a
/// regular cadence with similar amounts.
///
/// Pure functions only (no I/O) so this is fully unit-testable.
class RecurringDetector {
  RecurringDetector._();

  /// Detect recurring subscriptions among [transactions] (debits only).
  ///
  /// A merchant qualifies when it has at least [minOccurrences] debits whose
  /// gaps are reasonably regular (average gap within [minGapDays]..[maxGapDays])
  /// and whose amounts are within [amountTolerance] of each other.
  static List<RecurringSubscription> detect(
    List<Transaction> transactions, {
    int minOccurrences = 2,
    double minGapDays = 6,
    double maxGapDays = 400,
    double amountTolerance = 0.15,
  }) {
    // Group debits by a normalized merchant key.
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      if (t.isCredit) continue;
      final key = _normalize(t.title);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(t);
    }

    final result = <RecurringSubscription>[];
    for (final entry in groups.entries) {
      final txns = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (txns.length < minOccurrences) continue;

      // Gaps between consecutive charges.
      final gaps = <int>[];
      for (var i = 1; i < txns.length; i++) {
        gaps.add(txns[i].date.difference(txns[i - 1].date).inDays);
      }
      final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      if (avgGap < minGapDays || avgGap > maxGapDays) continue;

      // Amount consistency: all within tolerance of the median.
      final amounts = txns.map((t) => t.amount).toList()..sort();
      final median = amounts[amounts.length ~/ 2];
      final consistent = amounts.every(
        (a) => (a - median).abs() <= median * amountTolerance + 1,
      );
      if (!consistent) continue;

      final last = txns.last;
      result.add(RecurringSubscription(
        merchant: last.title,
        categoryId: last.categoryId,
        typicalAmount: median,
        occurrences: txns.length,
        lastDate: last.date,
        averageGapDays: avgGap,
      ));
    }

    // Most expensive commitments first.
    result.sort((a, b) => b.typicalAmount.compareTo(a.typicalAmount));
    return result;
  }

  /// Estimated total monthly commitment across all detected subscriptions,
  /// normalizing each to a per-month figure.
  static double monthlyCommitment(List<RecurringSubscription> subs) {
    double total = 0;
    for (final s in subs) {
      final perMonth = s.averageGapDays <= 0
          ? s.typicalAmount
          : s.typicalAmount * (30.4 / s.averageGapDays);
      total += perMonth;
    }
    return total;
  }

  /// Normalizes a merchant title for grouping: lowercase, strip trailing
  /// reference numbers and extra whitespace.
  static String _normalize(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[#*]?\d{3,}'), '') // ref numbers
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
