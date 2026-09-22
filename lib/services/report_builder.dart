import '../models/category.dart';
import '../models/transaction.dart';

/// A summary of one period's activity, used to render the shareable card.
class SpendReport {
  const SpendReport({
    required this.periodLabel,
    required this.income,
    required this.expense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.txnCount,
  });

  final String periodLabel;
  final double income;
  final double expense;
  final Category? topCategory;
  final double topCategoryAmount;
  final int txnCount;

  double get net => income - expense;
  double get savingsRate =>
      income <= 0 ? 0 : ((income - expense) / income).clamp(-1, 1) * 100;
}

/// Builds a [SpendReport] from transactions for a given month offset
/// (0 = this month, 1 = last month).
class ReportBuilder {
  ReportBuilder._();

  static SpendReport forMonth(
    List<Transaction> txns, {
    int monthsAgo = 0,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final start = DateTime(ref.year, ref.month - monthsAgo);
    final end = DateTime(ref.year, ref.month - monthsAgo + 1);

    double income = 0, expense = 0;
    var count = 0;
    final byCat = <String, double>{};

    for (final t in txns) {
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      count++;
      if (t.isCredit) {
        income += t.amount;
      } else {
        expense += t.amount;
        byCat.update(t.categoryId, (v) => v + t.amount,
            ifAbsent: () => t.amount);
      }
    }

    Category? topCat;
    double topAmt = 0;
    if (byCat.isNotEmpty) {
      final top = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      topCat = Categories.byId(top.key);
      topAmt = top.value;
    }

    final label = _monthLabel(start);
    return SpendReport(
      periodLabel: label,
      income: income,
      expense: expense,
      topCategory: topCat,
      topCategoryAmount: topAmt,
      txnCount: count,
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}
