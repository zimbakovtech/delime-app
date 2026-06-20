import '../models/balance.dart';
import '../models/person.dart';
import '../models/purchase.dart';

/// Pure functions that derive balances and the minimum-transaction
/// settlement plan from the raw people + purchases data.
class SettlementService {
  /// Computes each person's paid / owed / net totals across all purchases.
  /// Every person is included, even if they have no activity.
  static List<Balance> computeBalances(
    List<Person> people,
    List<Purchase> purchases,
  ) {
    final paid = <String, int>{for (final p in people) p.id: 0};
    final owed = <String, int>{for (final p in people) p.id: 0};

    for (final purchase in purchases) {
      for (final c in purchase.payers) {
        paid[c.personId] = (paid[c.personId] ?? 0) + c.amountCents;
      }
      for (final c in purchase.splits) {
        owed[c.personId] = (owed[c.personId] ?? 0) + c.amountCents;
      }
    }

    return people
        .map((p) => Balance(
              personId: p.id,
              paidCents: paid[p.id] ?? 0,
              owedCents: owed[p.id] ?? 0,
            ))
        .toList();
  }

  /// Greedy minimum-transaction settlement: repeatedly match the biggest
  /// debtor with the biggest creditor until everyone is balanced.
  static List<Settlement> computeSettlements(List<Balance> balances) {
    // Mutable working copies of non-zero balances.
    final creditors = balances
        .where((b) => b.netCents > 0)
        .map((b) => _Node(b.personId, b.netCents))
        .toList();
    final debtors = balances
        .where((b) => b.netCents < 0)
        .map((b) => _Node(b.personId, -b.netCents))
        .toList();

    final settlements = <Settlement>[];

    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      // Biggest creditor and biggest debtor.
      creditors.sort((a, b) => b.amount.compareTo(a.amount));
      debtors.sort((a, b) => b.amount.compareTo(a.amount));

      final creditor = creditors.first;
      final debtor = debtors.first;
      final amount =
          creditor.amount < debtor.amount ? creditor.amount : debtor.amount;

      settlements.add(Settlement(
        fromPersonId: debtor.id,
        toPersonId: creditor.id,
        amountCents: amount,
      ));

      creditor.amount -= amount;
      debtor.amount -= amount;

      if (creditor.amount == 0) creditors.removeAt(0);
      if (debtor.amount == 0) debtors.removeAt(0);
    }

    return settlements;
  }
}

class _Node {
  final String id;
  int amount;
  _Node(this.id, this.amount);
}
