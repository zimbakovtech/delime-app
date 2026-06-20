import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/services/settlement_service.dart';
import 'package:delime/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Four friends from the spec's example scenario.
  const john = Person(id: 'john', name: 'John', colorValue: 0xFF34D399);
  const eve = Person(id: 'eve', name: 'Eve', colorValue: 0xFF60A5FA);
  const marc = Person(id: 'marc', name: 'Marc', colorValue: 0xFFF472B6);
  const amy = Person(id: 'amy', name: 'Amy', colorValue: 0xFFFBBF24);
  final people = [john, eve, marc, amy];

  group('example scenario — €10 dinner, Marc & John pay €5 each', () {
    const dinner = Purchase(
      id: 'p1',
      name: 'Dinner',
      totalCents: 1000,
      createdAt: 0,
      payers: [
        Contribution(personId: 'marc', amountCents: 500),
        Contribution(personId: 'john', amountCents: 500),
      ],
      splits: [
        Contribution(personId: 'john', amountCents: 250),
        Contribution(personId: 'eve', amountCents: 250),
        Contribution(personId: 'marc', amountCents: 250),
        Contribution(personId: 'amy', amountCents: 250),
      ],
    );

    test('balances match the spec', () {
      final balances =
          SettlementService.computeBalances(people, [dinner]);
      int net(String id) =>
          balances.firstWhere((b) => b.personId == id).netCents;

      expect(net('john'), 250); // +€2.50
      expect(net('eve'), -250); // −€2.50
      expect(net('marc'), 250); // +€2.50
      expect(net('amy'), -250); // −€2.50
    });

    test('settlement is two transactions: Eve→John, Amy→Marc', () {
      final balances =
          SettlementService.computeBalances(people, [dinner]);
      final settlements = SettlementService.computeSettlements(balances);

      expect(settlements.length, 2);
      for (final s in settlements) {
        expect(s.amountCents, 250);
        expect(['eve', 'amy'].contains(s.fromPersonId), isTrue);
        expect(['john', 'marc'].contains(s.toPersonId), isTrue);
      }
      // No debtor pays more than they owe; totals net to zero.
      final paid =
          settlements.fold<int>(0, (sum, s) => sum + s.amountCents);
      expect(paid, 500);
    });
  });

  group('rounding', () {
    test('splitEqually distributes the leftover cent', () {
      expect(Money.splitEqually(1000, 3), [334, 333, 333]);
      expect(Money.splitEqually(1000, 3).reduce((a, b) => a + b), 1000);
      expect(Money.splitEqually(100, 4), [25, 25, 25, 25]);
    });
  });

  group('currency conversion (1 EUR = 61.5 MKD)', () {
    test('MKD input converts to EUR cents', () {
      expect(Money.mkdToCents(61.5), 100);
      expect(Money.eurToCents(2.5), 250);
    });
  });

  test('single-person trip still settles (no transactions)', () {
    final solo = [john];
    const purchase = Purchase(
      id: 'p',
      name: 'Coffee',
      totalCents: 300,
      createdAt: 0,
      payers: [Contribution(personId: 'john', amountCents: 300)],
      splits: [Contribution(personId: 'john', amountCents: 300)],
    );
    final balances =
        SettlementService.computeBalances(solo, [purchase]);
    expect(balances.single.netCents, 0);
    expect(SettlementService.computeSettlements(balances), isEmpty);
  });
}
