import 'package:flutter/material.dart';

/// Expense categories. A purchase carries a free-text category string that is
/// either one of [builtIns] or a user-entered custom label.
class ExpenseCategory {
  /// The default category for a new or migrated purchase.
  static const fallback = 'Other';

  /// Built-in categories offered in the picker, in display order.
  static const List<String> builtIns = [
    'Food',
    'Drinks',
    'Transport',
    'Accommodation',
    'Groceries',
    'Activities',
    'Shopping',
    'Other',
  ];

  static bool isBuiltIn(String category) => builtIns.contains(category);

  /// An icon for [category] — a known glyph for built-ins, a generic tag for
  /// custom labels.
  static IconData iconFor(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Drinks':
        return Icons.local_bar_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Accommodation':
        return Icons.hotel_outlined;
      case 'Groceries':
        return Icons.shopping_basket_outlined;
      case 'Activities':
        return Icons.hiking_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Other':
        return Icons.category_outlined;
      default:
        return Icons.sell_outlined; // custom label
    }
  }
}
