import 'package:delime/utils/categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in set is the documented eight, in order', () {
    expect(ExpenseCategory.builtIns, [
      'Food',
      'Drinks',
      'Transport',
      'Accommodation',
      'Groceries',
      'Activities',
      'Shopping',
      'Other',
    ]);
  });

  test('isBuiltIn distinguishes built-ins from custom labels', () {
    expect(ExpenseCategory.isBuiltIn('Food'), isTrue);
    expect(ExpenseCategory.isBuiltIn('Other'), isTrue);
    expect(ExpenseCategory.isBuiltIn('Souvenirs'), isFalse);
  });

  test('iconFor maps known categories and falls back for custom', () {
    expect(ExpenseCategory.iconFor('Food'), Icons.restaurant_outlined);
    expect(ExpenseCategory.iconFor('Transport'), Icons.directions_car_outlined);
    expect(ExpenseCategory.iconFor('Souvenirs'), Icons.sell_outlined);
  });
}
