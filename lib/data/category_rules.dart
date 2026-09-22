import '../models/category.dart';

/// Maps a merchant / payee name to a [Category].
///
/// This is what makes auto-categorization feel "magic": we match well-known
/// brand keywords first, then fall back to [Categories.other]. Rules are
/// intentionally simple substring checks so they're fast and easy to extend.
class CategoryRules {
  CategoryRules._();

  /// keyword -> categoryId. Keywords are matched case-insensitively against
  /// the merchant string.
  static const Map<String, String> _keywordToCategory = {
    // Food & dining
    'zomato': 'food',
    'swiggy': 'food',
    'dominos': 'food',
    'mcdonald': 'food',
    'kfc': 'food',
    'starbucks': 'food',
    'restaurant': 'food',
    'cafe': 'food',
    'eatery': 'food',
    'dineout': 'food',

    // Groceries
    'bigbasket': 'groceries',
    'blinkit': 'groceries',
    'zepto': 'groceries',
    'grofers': 'groceries',
    'dmart': 'groceries',
    'reliance fresh': 'groceries',
    'more retail': 'groceries',

    // Shopping
    'amazon': 'shopping',
    'flipkart': 'shopping',
    'myntra': 'shopping',
    'ajio': 'shopping',
    'meesho': 'shopping',
    'nykaa': 'shopping',
    'dribbble': 'shopping',
    'figma': 'shopping',

    // Travel
    'uber': 'travel',
    'ola': 'travel',
    'rapido': 'travel',
    'irctc': 'travel',
    'makemytrip': 'travel',
    'goibibo': 'travel',
    'indigo': 'travel',
    'redbus': 'travel',
    'petrol': 'travel',
    'fuel': 'travel',
    'hpcl': 'travel',
    'iocl': 'travel',
    'bpcl': 'travel',

    // Bills & utilities
    'electricity': 'bills',
    'recharge': 'bills',
    'airtel': 'bills',
    'jio': 'bills',
    'vodafone': 'bills',
    'vi ': 'bills',
    'bses': 'bills',
    'tata power': 'bills',
    'gas': 'bills',
    'broadband': 'bills',
    'act fibernet': 'bills',

    // Entertainment
    'netflix': 'entertainment',
    'spotify': 'entertainment',
    'hotstar': 'entertainment',
    'prime video': 'entertainment',
    'bookmyshow': 'entertainment',
    'youtube': 'entertainment',
    'pvr': 'entertainment',

    // Health
    'pharmacy': 'health',
    'apollo': 'health',
    'pharmeasy': 'health',
    '1mg': 'health',
    'hospital': 'health',
    'clinic': 'health',
    'practo': 'health',
  };

  /// Resolve a category id from a merchant string. Falls back to a sensible
  /// default: 'income' for credits, 'other' for debits.
  static String categorize(String merchant, {required bool isCredit}) {
    final m = merchant.toLowerCase();
    for (final entry in _keywordToCategory.entries) {
      if (m.contains(entry.key)) return entry.value;
    }
    if (isCredit) return Categories.income.id;
    return Categories.other.id;
  }
}
