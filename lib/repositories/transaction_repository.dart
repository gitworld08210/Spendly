import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/supabase_config.dart';

/// Aggregated totals for a period, used by the dashboard and stats.
class PeriodSummary {
  const PeriodSummary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  double get balance => income - expense;

  /// Share of the income+expense total that each side represents (0..100).
  double get incomePercent {
    final total = income + expense;
    return total == 0 ? 0 : (income / total) * 100;
  }

  double get expensePercent {
    final total = income + expense;
    return total == 0 ? 0 : (expense / total) * 100;
  }
}

/// Single source of truth for transactions.
///
/// A ChangeNotifier singleton holding an in-memory cache backed by Supabase.
/// Real, per-user data is loaded after login; a brand-new user simply starts
/// with an empty list. The cache reloads automatically whenever auth state
/// changes (login / logout). Every getter is synchronous so the UI reads
/// instantly.
class TransactionRepository extends ChangeNotifier {
  TransactionRepository._() {
    // Reload the cache on every auth change (sign-in loads the user's data,
    // sign-out clears it). Wrapped in try/catch so the singleton is safe to
    // construct in unit tests where Supabase hasn't been initialized.
    try {
      if (SupabaseConfig.isConfigured) {
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
          _hydrated = false;
          _items = const [];
          hydrate();
        });
      }
    } catch (_) {
      // Supabase not initialized (e.g. tests) — cache stays empty until used.
    }
    hydrate();
  }

  static final TransactionRepository instance = TransactionRepository._();

  List<Transaction> _items = const [];
  bool _hydrated = false;

  /// All transactions, newest first.
  List<Transaction> get all => List.unmodifiable(_items);

  /// The most recent [count] transactions.
  List<Transaction> recent([int count = 5]) => _items.take(count).toList();

  /// Net balance = sum of all credits minus debits for this user.
  double get balance => _items.fold(0.0, (sum, t) => sum + t.signedAmount);

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Not initialized (e.g. unit tests).
    }
  }

  bool get _hasSession => _client?.auth.currentUser != null;

  // --- Reads / summaries ----------------------------------------------------

  /// Summary for transactions within [from, to].
  PeriodSummary summaryBetween(DateTime from, DateTime to) {
    double income = 0, expense = 0;
    for (final t in _items) {
      if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
      if (t.isCredit) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return PeriodSummary(income: income, expense: expense);
  }

  /// Total spend per category (debits only) within [from, to], sorted desc.
  List<MapEntry<Category, double>> topSpending(
    DateTime from,
    DateTime to, {
    int limit = 5,
  }) {
    final totals = <String, double>{};
    for (final t in _items) {
      if (t.isCredit) continue;
      if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
      totals.update(t.categoryId, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }
    final entries = totals.entries
        .map((e) => MapEntry(Categories.byId(e.key), e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  // --- Mutations ------------------------------------------------------------

  /// Adds a transaction (manual or SMS-derived). Optimistic: updates the
  /// cache immediately, then persists to Supabase if available.
  Future<void> add(Transaction txn) async {
    _items = [txn, ..._items];
    _sort();
    notifyListeners();
    await _persistInsert(txn);
  }

  /// Adds an SMS-derived transaction only if we haven't already stored the
  /// same raw message (dedupe so re-scanning is safe).
  Future<bool> addFromSms(Transaction txn) async {
    final duplicate = txn.rawSms != null &&
        _items.any((t) => t.rawSms == txn.rawSms);
    if (duplicate) return false;
    await add(txn);
    return true;
  }

  Future<void> update(Transaction txn) async {
    _items = [
      for (final t in _items) if (t.id == txn.id) txn else t,
    ];
    _sort();
    notifyListeners();

    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      await client.from('transactions').update(txn.toJson()).eq('id', txn.id);
    } catch (e) {
      debugPrint('TransactionRepository.update failed: $e');
    }
  }

  Future<void> remove(String id) async {
    _items = _items.where((t) => t.id != id).toList();
    notifyListeners();

    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      await client.from('transactions').delete().eq('id', id);
    } catch (e) {
      debugPrint('TransactionRepository.remove failed: $e');
    }
  }

  /// Removes SMS-imported transactions dated before [cutoff]. Used to clean up
  /// old inbox messages that were pulled in before the install-date cutoff
  /// existed. Returns how many were removed.
  Future<int> removeSmsImportedBefore(DateTime cutoff) async {
    final toRemove = _items
        .where((t) => t.source == TxnSource.sms && t.date.isBefore(cutoff))
        .map((t) => t.id)
        .toList();
    if (toRemove.isEmpty) return 0;

    _items = _items.where((t) => !toRemove.contains(t.id)).toList();
    notifyListeners();

    final client = _client;
    if (client != null && _hasSession) {
      try {
        await client
            .from('transactions')
            .delete()
            .inFilter('id', toRemove);
      } catch (e) {
        debugPrint('TransactionRepository.removeSmsImportedBefore failed: $e');
      }
    }
    return toRemove.length;
  }

  // --- Supabase hydration ---------------------------------------------------

  /// Loads the signed-in user's rows into the cache. A new user with no rows
  /// simply ends up with an empty list (the UI shows an empty state). No-ops
  /// when there's no session.
  Future<void> hydrate() async {
    if (_hydrated) return;
    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      final rows = await client
          .from('transactions')
          .select()
          .order('date', ascending: false);
      _items = (rows as List)
          .map((r) => Transaction.fromJson(r as Map<String, dynamic>))
          .toList();
      _sort();
      _hydrated = true;
      notifyListeners();
    } catch (e) {
      debugPrint('TransactionRepository.hydrate failed: $e');
    }
  }

  Future<void> _persistInsert(Transaction txn) async {
    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      final payload = txn.toJson()
        ..['user_id'] = client.auth.currentUser!.id;
      await client.from('transactions').insert(payload);
    } catch (e) {
      debugPrint('TransactionRepository._persistInsert failed: $e');
    }
  }

  void _sort() => _items.sort((a, b) => b.date.compareTo(a.date));
}
