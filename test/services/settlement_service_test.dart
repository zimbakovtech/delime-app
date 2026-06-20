import 'package:delime/models/balance.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/services/settlement_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_data.dart';

int _net(List<Balance> balances, String id) =>
    balances.firstWhere((b) => b.personId == id).netCents;

void main() {
  group('computeBalances', () {
    test('matches the spec example', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      expect(_net(balances, 'john'), 250);
      expect(_net(balances, 'eve'), -250);
      expect(_net(balances, 'marc'), 250);
      expect(_net(balances, 'amy'), -250);
    });

    test('paid and owed are tracked separately', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      final johnBalance = balances.firstWhere((b) => b.personId == 'john');
      expect(johnBalance.paidCents, 500);
      expect(johnBalance.owedCents, 250);
      expect(johnBalance.isCreditor, isTrue);
    });

    test('includes people with no activity as settled', () {
      final balances = SettlementService.computeBalances(fourFriends, []);
      expect(balances, hasLength(4));
      expect(balances.every((b) => b.isSettled), isTrue);
    });

    test('a payer excluded from the split is a pure creditor', () {
      // Marc buys a €10 gift for Eve and Amy; Marc is not in the split.
      const gift = Purchase(
        id: 'gift',
        name: 'Gift',
        totalCents: 1000,
        createdAt: 1,
        payers: [Contribution(personId: 'marc', amountCents: 1000)],
        splits: [
          Contribution(personId: 'eve', amountCents: 500),
          Contribution(personId: 'amy', amountCents: 500),
        ],
      );
      final balances = SettlementService.computeBalances(fourFriends, [gift]);
      expect(_net(balances, 'marc'), 1000);
      expect(_net(balances, 'eve'), -500);
      expect(_net(balances, 'amy'), -500);
      expect(_net(balances, 'john'), 0);
    });
  });

  group('computeSettlements', () {
    test('spec example settles in two transactions', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      final settlements = SettlementService.computeSettlements(balances);

      expect(settlements, hasLength(2));
      expect(settlements.every((s) => s.amountCents == 250), isTrue);
      for (final s in settlements) {
        expect(['eve', 'amy'], contains(s.fromPersonId));
        expect(['john', 'marc'], contains(s.toPersonId));
      }
    });

    test('returns nothing when everyone is already balanced', () {
      const evenSplit = Purchase(
        id: 'e',
        name: 'Even',
        totalCents: 400,
        createdAt: 1,
        payers: [
          Contribution(personId: 'john', amountCents: 200),
          Contribution(personId: 'eve', amountCents: 200),
        ],
        splits: [
          Contribution(personId: 'john', amountCents: 200),
          Contribution(personId: 'eve', amountCents: 200),
        ],
      );
      final balances = SettlementService.computeBalances(
        [john, eve],
        [evenSplit],
      );
      expect(SettlementService.computeSettlements(balances), isEmpty);
    });

    test('one creditor, many debtors needs (n-1) transactions', () {
      const lunch = Purchase(
        id: 'l',
        name: 'Lunch',
        totalCents: 3000,
        createdAt: 1,
        payers: [Contribution(personId: 'john', amountCents: 3000)],
        splits: [
          Contribution(personId: 'john', amountCents: 1000),
          Contribution(personId: 'eve', amountCents: 1000),
          Contribution(personId: 'marc', amountCents: 1000),
        ],
      );
      final balances = SettlementService.computeBalances(
        [john, eve, marc],
        [lunch],
      );
      final settlements = SettlementService.computeSettlements(balances);
      expect(settlements, hasLength(2));
      expect(settlements.every((s) => s.toPersonId == 'john'), isTrue);
      expect(settlements.every((s) => s.amountCents == 1000), isTrue);
    });

    test('never uses more than (creditors+debtors-1) transactions', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      final settlements = SettlementService.computeSettlements(balances);
      final involved = balances.where((b) => !b.isSettled).length;
      expect(settlements.length, lessThanOrEqualTo(involved - 1));
    });

    test('settlement amounts conserve money (sum == total positive net)', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      final settlements = SettlementService.computeSettlements(balances);
      final moved = settlements.fold<int>(0, (s, e) => s + e.amountCents);
      final owed = balances
          .where((b) => b.isCreditor)
          .fold<int>(0, (s, b) => s + b.netCents);
      expect(moved, owed);
    });

    test('empty input produces no settlements', () {
      expect(SettlementService.computeSettlements(const []), isEmpty);
      expect(
        SettlementService.computeSettlements(
          SettlementService.computeBalances(const <Person>[], const []),
        ),
        isEmpty,
      );
    });

    test('applying the plan zeroes every balance', () {
      final balances = SettlementService.computeBalances(fourFriends, [dinner]);
      final net = {for (final b in balances) b.personId: b.netCents};
      for (final s in SettlementService.computeSettlements(balances)) {
        net[s.fromPersonId] = net[s.fromPersonId]! + s.amountCents;
        net[s.toPersonId] = net[s.toPersonId]! - s.amountCents;
      }
      expect(net.values.every((v) => v == 0), isTrue);
    });
  });
}
