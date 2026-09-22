import 'package:flutter/material.dart';

import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

enum _Filter { all, income, expense }

/// Full transactions list with a simple filter and search.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        var items = repo.all;
        if (_filter == _Filter.income) {
          items = items.where((t) => t.isCredit).toList();
        } else if (_filter == _Filter.expense) {
          items = items.where((t) => !t.isCredit).toList();
        }
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          items =
              items.where((t) => t.title.toLowerCase().contains(q)).toList();
        }

        return SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'All Transactions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search merchant…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: AppColors.ink,
                          labelStyle: TextStyle(
                            color: _filter == f
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('No transactions found.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, 120),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) => TransactionTile(
                          txn: items[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailScreen(txn: items[i]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.income => 'Income',
        _Filter.expense => 'Expense',
      };
}
