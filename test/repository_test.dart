import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/repositories/transaction_repository.dart';
import 'package:paisatrack/services/sms_parser.dart';

/// These tests exercise the repository's in-memory logic without a live
/// Supabase session (network calls no-op). The cache starts empty for a fresh
/// user and mutations update it optimistically.
void main() {
  final repo = TransactionRepository.instance;

  test('cache starts empty (no mock seed for real users)', () {
    expect(repo.all, isEmpty);
  });

  test('add inserts and keeps list sorted newest-first', () async {
    await repo.add(Transaction(
      id: 'r-old',
      title: 'Older',
      amount: 10,
      type: TxnType.debit,
      categoryId: 'other',
      date: DateTime(2026, 1, 1),
    ));
    await repo.add(Transaction(
      id: 'r-new',
      title: 'Newer',
      amount: 20,
      type: TxnType.debit,
      categoryId: 'other',
      date: DateTime(2026, 6, 1),
    ));
    expect(repo.all.first.id, 'r-new');
    for (var i = 0; i < repo.all.length - 1; i++) {
      expect(
        !repo.all[i].date.isBefore(repo.all[i + 1].date),
        isTrue,
      );
    }
  });

  test('addFromSms dedupes identical raw messages', () async {
    const body = 'Rs.77.00 debited from a/c XX4021 to UniqueMerchantXYZ.';
    final txn1 = SmsParser.toTransaction(body)!;
    expect(await repo.addFromSms(txn1), isTrue);

    final txn2 = SmsParser.toTransaction(body)!;
    expect(await repo.addFromSms(txn2), isFalse,
        reason: 'same raw SMS should not be added twice');
  });

  test('period summary separates income and expense', () async {
    await repo.add(Transaction(
      id: 'r-income',
      title: 'Salary',
      amount: 1000,
      type: TxnType.credit,
      categoryId: 'income',
      date: DateTime(2026, 6, 2),
    ));
    final summary =
        repo.summaryBetween(DateTime(2026, 6, 1), DateTime(2026, 6, 30));
    expect(summary.income, greaterThan(0));
    expect(summary.expense, greaterThan(0));
  });

  test('topSpending excludes credits and is sorted descending', () {
    final top =
        repo.topSpending(DateTime(2020), DateTime(2030));
    for (var i = 0; i < top.length - 1; i++) {
      expect(top[i].value >= top[i + 1].value, isTrue);
    }
    expect(top.any((e) => e.key.id == 'income'), isFalse);
  });
}
