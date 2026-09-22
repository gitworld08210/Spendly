import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Lets the user set a monthly limit per category and see progress
/// (spent vs limit) for the current month, with over-budget highlighted.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgets = BudgetRepository.instance;
    final txns = TransactionRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: AnimatedBuilder(
        // Rebuild when either budgets or transactions change.
        animation: Listenable.merge([budgets, txns]),
        builder: (context, _) {
          final statuses = budgets.statusesThisMonth();
          final budgetedIds = statuses.map((s) => s.budget.categoryId).toSet();
          final unbudgeted = Categories.all
              .where((c) => c.id != 'income' && !budgetedIds.contains(c.id))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
            children: [
              const Text(
                'Set monthly limits and Spendly will warn you before you '
                'overspend.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (statuses.isNotEmpty) ...[
                const Text(
                  'Your budgets',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...statuses.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        status: s,
                        onTap: () => _editLimit(context, s.budget.categoryId,
                            existing: s.limit),
                      ),
                    )),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Text(
                'Add a budget',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...unbudgeted.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AddCategoryRow(
                      category: c,
                      onTap: () => _editLimit(context, c.id),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editLimit(BuildContext context, String categoryId,
      {double? existing}) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LimitSheet(categoryId: categoryId, existing: existing),
    );
    if (result != null) {
      if (result <= 0) {
        await BudgetRepository.instance.remove(categoryId);
      } else {
        await BudgetRepository.instance.setLimit(categoryId, result);
      }
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = status.category;
    final barColor = status.isOver
        ? AppColors.accentRed
        : status.isNear
            ? AppColors.accentOrange
            : AppColors.income;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  Text(
                    '${Formatters.money(status.spent)} / ${Formatters.money(status.limit)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: status.ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status.isOver
                    ? 'Over by ${Formatters.money(-status.remaining)}'
                    : '${Formatters.money(status.remaining)} left this month',
                style: TextStyle(
                  color: status.isOver
                      ? AppColors.accentRed
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      status.isOver ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCategoryRow extends StatelessWidget {
  const _AddCategoryRow({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(category.icon, color: category.color, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.categoryId, this.existing});

  final String categoryId;
  final double? existing;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.existing != null && widget.existing! > 0
        ? widget.existing!.toStringAsFixed(0)
        : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = Categories.byId(widget.categoryId);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(cat.icon, color: cat.color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  cat.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                prefixText: '₹ ',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (widget.existing != null && widget.existing! > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(0.0),
                      child: const Text('Remove',
                          style: TextStyle(color: AppColors.accentRed)),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final v = double.tryParse(_ctrl.text.trim()) ?? 0;
                        Navigator.of(context).pop(v);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                      ),
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
