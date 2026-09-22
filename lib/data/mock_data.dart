import '../models/transaction.dart';

/// Seed data used on first launch and when running without a Supabase session.
/// Mirrors the sample rows in the reference design (Dribbble Pro, Figma, etc.).
class MockData {
  MockData._();

  static const String demoName = 'Iqbal Hossain';
  static const double demoBalance = 5480.00;
  static const String demoCardLast4 = '402';

  static List<Transaction> transactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: 'seed-1',
        title: 'Dribbble Pro',
        amount: 145,
        type: TxnType.debit,
        categoryId: 'shopping',
        date: now.subtract(const Duration(days: 1, hours: 3)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-2',
        title: 'Figma',
        amount: 46,
        type: TxnType.debit,
        categoryId: 'shopping',
        date: now.subtract(const Duration(days: 4)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-3',
        title: 'iPhone 13',
        amount: 745,
        type: TxnType.debit,
        categoryId: 'shopping',
        date: now.subtract(const Duration(days: 6)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-4',
        title: 'Zomato',
        amount: 289,
        type: TxnType.debit,
        categoryId: 'food',
        date: now.subtract(const Duration(days: 2, hours: 5)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-5',
        title: 'Uber',
        amount: 210,
        type: TxnType.debit,
        categoryId: 'travel',
        date: now.subtract(const Duration(days: 3)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-6',
        title: 'Salary',
        amount: 42000,
        type: TxnType.credit,
        categoryId: 'income',
        date: now.subtract(const Duration(days: 8)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-7',
        title: 'Netflix',
        amount: 199,
        type: TxnType.debit,
        categoryId: 'entertainment',
        date: now.subtract(const Duration(days: 10)),
        source: TxnSource.sms,
        account: '••402',
      ),
      Transaction(
        id: 'seed-8',
        title: 'BigBasket',
        amount: 1240,
        type: TxnType.debit,
        categoryId: 'groceries',
        date: now.subtract(const Duration(days: 5)),
        source: TxnSource.manual,
        account: '••402',
      ),
    ];
  }
}
