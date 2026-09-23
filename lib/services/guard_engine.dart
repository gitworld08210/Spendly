import '../models/category.dart';
import '../models/guard_alert.dart';
import '../models/transaction.dart';
import 'recurring_detector.dart';

/// Paisa Guard — scans transactions for money at risk or waste:
///   • duplicate / double charges (same merchant + amount, close together)
///   • hidden bank charges / fees
///   • unused subscriptions (recurring, but stale)
///   • bill / category spikes vs the personal average
///   • unusual large one-off transactions
///
/// Pure functions only (no I/O), so it's deterministic and unit-testable.
/// This is Spendly's differentiator: it protects money, not just tracks it.
class GuardEngine {
  GuardEngine._();

  static GuardSummary scan(List<Transaction> txns, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final alerts = <GuardAlert>[];

    alerts.addAll(_duplicates(txns));
    alerts.addAll(_hiddenCharges(txns, ref));
    alerts.addAll(_unusedSubscriptions(txns, ref));
    alerts.addAll(_spikes(txns, ref));
    alerts.addAll(_unusual(txns, ref));

    alerts.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return (b.amountAtRisk + b.potentialSaving)
          .compareTo(a.amountAtRisk + a.potentialSaving);
    });

    final atRisk = alerts.fold(0.0, (s, a) => s + a.amountAtRisk);
    final saving = alerts.fold(0.0, (s, a) => s + a.potentialSaving);
    return GuardSummary(
      alerts: alerts,
      totalAtRisk: atRisk,
      totalPotentialSaving: saving,
    );
  }

  // --- 1. Duplicate / double charges ----------------------------------------

  static List<GuardAlert> _duplicates(List<Transaction> txns) {
    final out = <GuardAlert>[];
    final debits = txns.where((t) => !t.isCredit).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var i = 0; i < debits.length; i++) {
      for (var j = i + 1; j < debits.length; j++) {
        final a = debits[i], b = debits[j];
        final gap = b.date.difference(a.date);
        if (gap > const Duration(hours: 48)) break; // sorted; no closer later
        if (a.amount == b.amount &&
            _norm(a.title) == _norm(b.title) &&
            a.amount > 0) {
          out.add(GuardAlert(
            id: 'dup-${a.id}-${b.id}',
            kind: GuardKind.duplicateCharge,
            severity: GuardSeverity.high,
            title: 'Possible double charge',
            message:
                '${b.title} charged ₹${_fmt(b.amount)} twice within '
                '${_gapLabel(gap)}. If you only paid once, ask for a refund.',
            amountAtRisk: b.amount,
            transactionIds: [a.id, b.id],
          ));
        }
      }
    }
    return out;
  }

  // --- 2. Hidden bank charges / fees ----------------------------------------

  // Matched as whole words/phrases so we don't flag e.g. "coffee" for "fee".
  static final RegExp _feeRegex = RegExp(
    r'\b(charges?|fees?|penalty|gst|service tax|amc|'
    r'annual maintenance|sms alert|min(?:imum)? balance|non[- ]?maintenance)\b',
    caseSensitive: false,
  );

  static List<GuardAlert> _hiddenCharges(List<Transaction> txns, DateTime ref) {
    final since = DateTime(ref.year, ref.month - 2);
    final out = <GuardAlert>[];
    for (final t in txns) {
      if (t.isCredit || t.date.isBefore(since)) continue;
      final title = t.title;
      final raw = t.rawSms ?? '';
      final hit = _feeRegex.hasMatch(title) || _feeRegex.hasMatch(raw);
      if (hit && t.amount > 0) {
        out.add(GuardAlert(
          id: 'fee-${t.id}',
          kind: GuardKind.hiddenCharge,
          severity: GuardSeverity.medium,
          title: 'Bank charge detected',
          message:
              '₹${_fmt(t.amount)} looks like a fee/charge (${t.title}). '
              'Many such charges can be waived — worth checking with your bank.',
          amountAtRisk: t.amount,
          transactionIds: [t.id],
        ));
      }
    }
    return out;
  }

  // --- 3. Unused subscriptions ----------------------------------------------

  static List<GuardAlert> _unusedSubscriptions(
      List<Transaction> txns, DateTime ref) {
    final subs = RecurringDetector.detect(txns);
    final out = <GuardAlert>[];
    for (final s in subs) {
      // "Unused" heuristic: recurring but the last charge is old relative to
      // its cadence (i.e. it may have lapsed OR the user forgot about it), or
      // simply flag ongoing subscriptions so the user can review them.
      final monthlyCost = s.averageGapDays <= 0
          ? s.typicalAmount
          : s.typicalAmount * (30.4 / s.averageGapDays);
      out.add(GuardAlert(
        id: 'sub-${_norm(s.merchant)}',
        kind: GuardKind.unusedSubscription,
        severity: GuardSeverity.low,
        title: 'Review: ${s.merchant} subscription',
        message:
            '${s.merchant} charges about ₹${_fmt(monthlyCost)}/month. '
            'If you no longer use it, cancelling saves ₹${_fmt(monthlyCost * 12)}/year.',
        potentialSaving: monthlyCost,
        transactionIds: const [],
      ));
    }
    return out;
  }

  // --- 4. Bill / category spikes --------------------------------------------

  static List<GuardAlert> _spikes(List<Transaction> txns, DateTime ref) {
    final out = <GuardAlert>[];
    final thisStart = DateTime(ref.year, ref.month);
    final thisEnd = DateTime(ref.year, ref.month + 1);

    for (final cat in Categories.all) {
      if (cat.id == 'income') continue;
      final cur = _sum(txns, cat.id, thisStart, thisEnd);
      if (cur <= 0) continue;

      final past = <double>[];
      for (var m = 1; m <= 3; m++) {
        final s = DateTime(ref.year, ref.month - m);
        final e = DateTime(ref.year, ref.month - m + 1);
        final v = _sum(txns, cat.id, s, e);
        if (v > 0) past.add(v);
      }
      if (past.isEmpty) continue;
      final avg = past.reduce((a, b) => a + b) / past.length;
      if (avg <= 0) continue;

      if (cur > avg * 1.5 && cur - avg >= 500) {
        final pct = ((cur - avg) / avg * 100).round();
        out.add(GuardAlert(
          id: 'spike-${cat.id}',
          kind: GuardKind.spike,
          severity: GuardSeverity.medium,
          title: '${cat.name} bill spiked $pct%',
          message:
              '${cat.name} is ₹${_fmt(cur)} this month vs your usual '
              '₹${_fmt(avg)}. Worth checking for an error or overuse.',
          amountAtRisk: cur - avg,
        ));
      }
    }
    return out;
  }

  // --- 5. Unusual large one-off ---------------------------------------------

  static List<GuardAlert> _unusual(List<Transaction> txns, DateTime ref) {
    final since = DateTime(ref.year, ref.month - 3);
    final debits = txns
        .where((t) => !t.isCredit && !t.date.isBefore(since))
        .toList();
    if (debits.length < 8) return const []; // need history to judge "unusual"

    final amounts = debits.map((t) => t.amount).toList()..sort();
    final median = amounts[amounts.length ~/ 2];
    if (median <= 0) return const [];

    final out = <GuardAlert>[];
    final recentStart = DateTime(ref.year, ref.month);
    for (final t in debits) {
      if (t.date.isBefore(recentStart)) continue;
      // Flag a charge that's dramatically larger than the user's typical spend.
      if (t.amount >= median * 8 && t.amount >= 5000) {
        out.add(GuardAlert(
          id: 'unusual-${t.id}',
          kind: GuardKind.unusualTransaction,
          severity: GuardSeverity.high,
          title: 'Unusually large payment',
          message:
              '₹${_fmt(t.amount)} to ${t.title} is much bigger than your '
              'typical spend. If you didn\'t make this, act quickly.',
          amountAtRisk: t.amount,
          transactionIds: [t.id],
        ));
      }
    }
    return out;
  }

  // --- helpers --------------------------------------------------------------

  static double _sum(
      List<Transaction> txns, String categoryId, DateTime from, DateTime to) {
    double total = 0;
    for (final t in txns) {
      if (t.isCredit || t.categoryId != categoryId) continue;
      if (t.date.isBefore(from) || !t.date.isBefore(to)) continue;
      total += t.amount;
    }
    return total;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _gapLabel(Duration d) {
    if (d.inHours < 1) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} hr';
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
  }

  static String _fmt(double v) {
    final n = v.round().toString();
    // Simple Indian grouping.
    if (n.length <= 3) return n;
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final buf = <String>[];
    while (rest.length > 2) {
      buf.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    buf.insert(0, rest);
    return '${buf.join(',')},$last3';
  }
}
