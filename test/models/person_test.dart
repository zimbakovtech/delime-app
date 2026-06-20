import 'package:delime/models/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initials', () {
    String initialsOf(String name) =>
        Person(id: 'x', name: name, colorValue: 0).initials;

    test('single name uses the first letter', () {
      expect(initialsOf('John'), 'J');
      expect(initialsOf('eve'), 'E');
    });

    test('multiple words use first and last initials', () {
      expect(initialsOf('John Doe'), 'JD');
      expect(initialsOf('mary jane watson'), 'MW');
    });

    test('collapses extra whitespace', () {
      expect(initialsOf('  John   Doe  '), 'JD');
    });

    test('blank name falls back to a placeholder', () {
      expect(initialsOf('   '), '?');
      expect(initialsOf(''), '?');
    });
  });

  test('color getter wraps the stored ARGB value', () {
    const person = Person(id: 'x', name: 'A', colorValue: 0xFF34D399);
    expect(person.color, const Color(0xFF34D399));
  });

  test('copyWith updates fields but keeps the id', () {
    const person = Person(id: 'x', name: 'A', colorValue: 1);
    final updated = person.copyWith(name: 'B', colorValue: 2);
    expect(updated.id, 'x');
    expect(updated.name, 'B');
    expect(updated.colorValue, 2);
  });

  test('toMap / fromMap round-trip', () {
    const person = Person(id: 'x', name: 'Amy', colorValue: 0xFFFBBF24);
    final restored = Person.fromMap(person.toMap());
    expect(restored.id, person.id);
    expect(restored.name, person.name);
    expect(restored.colorValue, person.colorValue);
  });

  test('equality and hashCode are identity by id', () {
    const a = Person(id: 'same', name: 'A', colorValue: 1);
    const b = Person(id: 'same', name: 'Different', colorValue: 2);
    const c = Person(id: 'other', name: 'A', colorValue: 1);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });
}
