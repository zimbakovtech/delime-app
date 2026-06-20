import 'package:delime/models/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contribution', () {
    test('copyWith overrides selected fields', () {
      const c = Contribution(personId: 'a', amountCents: 100);
      expect(c.copyWith(amountCents: 250).personId, 'a');
      expect(c.copyWith(amountCents: 250).amountCents, 250);
      expect(c.copyWith(personId: 'b').personId, 'b');
    });
  });

  group('Purchase', () {
    const purchase = Purchase(
      id: 'p1',
      name: 'Taxi',
      totalCents: 900,
      createdAt: 42,
      payers: [Contribution(personId: 'a', amountCents: 900)],
      splits: [
        Contribution(personId: 'a', amountCents: 300),
        Contribution(personId: 'b', amountCents: 300),
        Contribution(personId: 'c', amountCents: 300),
      ],
    );

    test('payersTotal and splitsTotal sum the contributions', () {
      expect(purchase.payersTotal, 900);
      expect(purchase.splitsTotal, 900);
    });

    test('empty contributions total to zero', () {
      const empty = Purchase(
        id: 'p',
        name: 'x',
        totalCents: 0,
        createdAt: 0,
        payers: [],
        splits: [],
      );
      expect(empty.payersTotal, 0);
      expect(empty.splitsTotal, 0);
    });

    test('copyWith preserves id and createdAt', () {
      final updated = purchase.copyWith(name: 'Bus', totalCents: 800);
      expect(updated.id, 'p1');
      expect(updated.createdAt, 42);
      expect(updated.name, 'Bus');
      expect(updated.totalCents, 800);
    });

    test('toMap exposes the persisted columns', () {
      final map = purchase.toMap();
      expect(map['id'], 'p1');
      expect(map['name'], 'Taxi');
      expect(map['total'], 900);
      expect(map['created_at'], 42);
    });

    test('fromMap attaches the provided payers and splits', () {
      final restored = Purchase.fromMap(
        purchase.toMap(),
        payers: purchase.payers,
        splits: purchase.splits,
      );
      expect(restored.id, 'p1');
      expect(restored.totalCents, 900);
      expect(restored.payers, hasLength(1));
      expect(restored.splits, hasLength(3));
    });
  });
}
