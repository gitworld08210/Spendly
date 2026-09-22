import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget.dart';
import '../services/supabase_config.dart';
import '../utils/ids.dart';
import 'transaction_repository.dart';

/// Single source of truth for per-category monthly budgets.
///
/// Same conventions as [TransactionRepository]: a ChangeNotifier singleton
/// with a synchronous in-memory cache, hydrated from Supabase after login and
/// reloaded on auth changes. Safe to construct without Supabase initialized
/// (unit tests) — all client access is guarded.
class BudgetRepository extends ChangeNotifier {
  BudgetRepository._() {
    try {
      if (SupabaseConfig.isConfigured) {
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
          _hydrated = false;
          _items = const [];
          hydrate();
        });
      }
    } catch (_) {
      // Supabase not initialized (tests) — cache stays empty.
    }
    hydrate();
  }

  static final BudgetRepository instance = BudgetRepository._();

  List<Budget> _items = const [];
  bool _hydrated = false;

  List<Budget> get all => List.unmodifiable(_items);

  Budget? forCategory(String categoryId) {
    for (final b in _items) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get _hasSession => _client?.auth.currentUser != null;

  // --- Derived: budget vs actual spend this month ---------------------------

  /// Current-month status for every budget, computed against the transaction
  /// repository. Over-budget items sort first.
  List<BudgetStatus> statusesThisMonth() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final summarySpentByCat = _spentByCategory(monthStart, now);

    final statuses = _items
        .map((b) => BudgetStatus(
              budget: b,
              spent: summarySpentByCat[b.categoryId] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    return statuses;
  }

  /// Budgets that are over or near their limit this month (for alerts).
  List<BudgetStatus> alertsThisMonth() =>
      statusesThisMonth().where((s) => s.isOver || s.isNear).toList();

  Map<String, double> _spentByCategory(DateTime from, DateTime to) {
    final totals = <String, double>{};
    for (final t in TransactionRepository.instance.all) {
      if (t.isCredit) continue;
      if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
      totals.update(t.categoryId, (v) => v + t.amount,
          ifAbsent: () => t.amount);
    }
    return totals;
  }

  // --- Mutations ------------------------------------------------------------

  /// Creates or updates the budget for a category (one budget per category).
  Future<void> setLimit(String categoryId, double monthlyLimit) async {
    final existing = forCategory(categoryId);
    final budget = existing?.copyWith(monthlyLimit: monthlyLimit) ??
        Budget(
          id: newId(),
          categoryId: categoryId,
          monthlyLimit: monthlyLimit,
        );

    _items = [
      for (final b in _items)
        if (b.categoryId != categoryId) b,
      budget,
    ];
    notifyListeners();

    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      final payload = budget.toJson()
        ..['user_id'] = client.auth.currentUser!.id;
      await client
          .from('budgets')
          .upsert(payload, onConflict: 'user_id,category_id');
    } catch (e) {
      debugPrint('BudgetRepository.setLimit failed: $e');
    }
  }

  Future<void> remove(String categoryId) async {
    final existing = forCategory(categoryId);
    if (existing == null) return;
    _items = _items.where((b) => b.categoryId != categoryId).toList();
    notifyListeners();

    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      await client.from('budgets').delete().eq('id', existing.id);
    } catch (e) {
      debugPrint('BudgetRepository.remove failed: $e');
    }
  }

  // --- Hydration ------------------------------------------------------------

  Future<void> hydrate() async {
    if (_hydrated) return;
    final client = _client;
    if (client == null || !_hasSession) return;
    try {
      final rows = await client.from('budgets').select();
      _items = (rows as List)
          .map((r) => Budget.fromJson(r as Map<String, dynamic>))
          .toList();
      _hydrated = true;
      notifyListeners();
    } catch (e) {
      debugPrint('BudgetRepository.hydrate failed: $e');
    }
  }
}
