import 'package:flutter/material.dart';

/// A spending/income category with its display glyph and color.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The built-in categories PaisaTrack auto-assigns from SMS merchant names.
class Categories {
  Categories._();

  static const food = Category(
    id: 'food',
    name: 'Food & Dining',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFF8A34),
  );
  static const shopping = Category(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF7C5CFC),
  );
  static const travel = Category(
    id: 'travel',
    name: 'Travel',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF2FB1F0),
  );
  static const bills = Category(
    id: 'bills',
    name: 'Bills & Utilities',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFF5432C),
  );
  static const entertainment = Category(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_rounded,
    color: Color(0xFFEC4899),
  );
  static const groceries = Category(
    id: 'groceries',
    name: 'Groceries',
    icon: Icons.local_grocery_store_rounded,
    color: Color(0xFF27C093),
  );
  static const health = Category(
    id: 'health',
    name: 'Health',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF4444),
  );
  static const income = Category(
    id: 'income',
    name: 'Income',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF27C093),
  );
  static const transfer = Category(
    id: 'transfer',
    name: 'Transfer',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF64748B),
  );
  static const other = Category(
    id: 'other',
    name: 'Other',
    icon: Icons.category_rounded,
    color: Color(0xFF8A8D96),
  );

  static const List<Category> all = [
    food,
    shopping,
    travel,
    bills,
    entertainment,
    groceries,
    health,
    income,
    transfer,
    other,
  ];

  static Category byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => other);
}
