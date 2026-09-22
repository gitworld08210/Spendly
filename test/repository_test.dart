import 'package:flutter_test/flutter_test.dart';
import 'package:paisatrack/models/transaction.dart';
import 'package:paisatrack/repositories/transaction_repository.dart';
import 'package:paisatrack/services/sms_parser.dart';

void main() {
  final repo = TransactionRepository.instance;

  test('seed data is loaded and sorted newest-first', () {
    expect(repo.all, isNotEmpty);
    for (var i = 0; i < repo.all.length - 1; i++) {
      expect(
        repo.all[i].date.isAfter(repo.all[i + 1].date) ||
            repo.all[i].date.isAtSameMomentAs(repo.all[i + 1].date),
        isTrue,
      );
    }
  });

  test('addFromSms dedupes identical raw messages', () async {
    const body = 'Rs.77.00 debited from a/c XX4021 to UniqueMerchantXYZ.';
    final txn1 = SmsParser.toTransaction(body)!;
    final added1 = await repo.addFromSms(txn1);
    expect(added1, isTrue);

    final txn2 = SmsParser.toTransaction(body)!;
    final added2 = await repo.addFromSms(txn2);
    expect(added2, isFalse, reason: 'same raw SMS should not be added twice');
  });

  test('period summary separates income and expense', () {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 365));
    final summary = repo.summaryBetween(from, now);
    expect(summary.income, greaterThan(0));
    expect(summary.expense, greaterThan(0));
  });

  test('topSpending excludes credits and is sorted descending', () {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 365));
    final top = repo.topSpending(from, now);
    expect(top, isNotEmpty);
    for (var i = 0; i < top.length - 1; i++) {
      expect(top[i].value >= top[i + 1].value, isTrue);
    }
    // Income category should never appear in spending.
    expect(top.any((e) => e.key.id == 'income'), isFalse);
  });

  test('manual add inserts at front', () async {
    final before = repo.all.length;
    await repo.add(
      Transaction(
        id: 'test-manual-1',
        title: 'Test Manual',
        amount: 10,
        type: TxnType.debit,
        categoryId: 'other',
        date: DateTime.now().add(const Duration(minutes: 1)),
      ),
    );
    expect(repo.all.length, before + 1);
    expect(repo.all.first.id, 'test-manual-1');
  });
}
