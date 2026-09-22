import 'package:flutter/foundation.dart' hide Category;

import 'category.dart';

/// A per-category monthly spending limit.
@immutable
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
  });

  final String id;
  final String categoryId;
  final double monthlyLimit;

  Category get category => Categories.byId(categoryId);

  Budget copyWith({String? id, String? categoryId, double? monthlyLimit}) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'monthly_limit': monthlyLimit,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        monthlyLimit: (json['monthly_limit'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) => other is Budget && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A budget paired with how much has been spent this month against it.
@immutable
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spent,
  });

  final Budget budget;
  final double spent;

  Category get category => budget.category;
  double get limit => budget.monthlyLimit;
  double get remaining => (limit - spent);

  /// 0..(>1) — fraction of the limit used.
  double get ratio => limit <= 0 ? 0 : spent / limit;

  bool get isOver => spent > limit;

  /// "Near" = used 80% or more but not yet over.
  bool get isNear => !isOver && ratio >= 0.8;
}
