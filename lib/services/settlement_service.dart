import 'package:delime/models/balance.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/settlement_record.dart';

/// Pure functions that derive balances and settlement plans from the raw
/// people + purchases data. No state, no I/O — identical on device and (later)
/// on a server.
class SettlementService {
  /// Computes each person's paid / owed / net totals across all purchases.
  /// Recorded [settlements] are folded into each person's outstanding net
  /// (a payment reduces the payer's debt and the recipient's credit).
  /// Every person is included, even if they have no activity.
  static List<Balance> computeBalances(
    List<Person> people,
    List<Purchase> purchases, {
    List<SettlementRecord> settlements = const [],
  }) {
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

    final settledOut = <String, int>{};
    final settledIn = <String, int>{};
    for (final s in settlements) {
      settledOut[s.fromPersonId] =
          (settledOut[s.fromPersonId] ?? 0) + s.amountCents;
      settledIn[s.toPersonId] = (settledIn[s.toPersonId] ?? 0) + s.amountCents;
    }

    return people
        .map(
          (p) => Balance(
            personId: p.id,
            paidCents: paid[p.id] ?? 0,
            owedCents: owed[p.id] ?? 0,
            settledCents: (settledOut[p.id] ?? 0) - (settledIn[p.id] ?? 0),
          ),
        )
        .toList();
  }

  /// Greedy minimum-transaction settlement ("simplify debts"): repeatedly match
  /// the biggest debtor with the biggest creditor until everyone is balanced.
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
      final amount = creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount;

      settlements.add(
        Settlement(
          fromPersonId: debtor.id,
          toPersonId: creditor.id,
          amountCents: amount,
        ),
      );

      creditor.amount -= amount;
      debtor.amount -= amount;

      if (creditor.amount == 0) creditors.removeAt(0);
      if (debtor.amount == 0) debtors.removeAt(0);
    }

    return settlements;
  }

  /// Direct settlement (simplify-debts **off**): per-expense debtor→creditor
  /// edges, summed and netted **per pair only** — debts are never routed
  /// through a third person the way [computeSettlements] does. Recorded
  /// [settlements] reduce the matching pair's outstanding amount.
  static List<Settlement> computeDirectSettlements(
    List<Person> people,
    List<Purchase> purchases, {
    List<SettlementRecord> settlements = const [],
  }) {
    // directed[from][to] = cents `from` owes `to`.
    final directed = <String, Map<String, int>>{};
    void add(String from, String to, int amount) {
      if (amount == 0) return;
      (directed[from] ??= {}).update(
        to,
        (v) => v + amount,
        ifAbsent: () => amount,
      );
    }

    for (final purchase in purchases) {
      // Each person's net within this single purchase.
      final net = <String, int>{};
      for (final c in purchase.payers) {
        net[c.personId] = (net[c.personId] ?? 0) + c.amountCents;
      }
      for (final c in purchase.splits) {
        net[c.personId] = (net[c.personId] ?? 0) - c.amountCents;
      }
      final perPurchase = net.entries
          .map(
            (e) => Balance(
              personId: e.key,
              paidCents: e.value > 0 ? e.value : 0,
              owedCents: e.value < 0 ? -e.value : 0,
            ),
          )
          .toList();
      for (final s in computeSettlements(perPurchase)) {
        add(s.fromPersonId, s.toPersonId, s.amountCents);
      }
    }

    // A recorded payment from A to B cancels A's outstanding debt to B.
    for (final s in settlements) {
      add(s.toPersonId, s.fromPersonId, s.amountCents);
    }

    // Net opposing directions within each unordered pair.
    final ids = <String>{
      ...directed.keys,
      for (final m in directed.values) ...m.keys,
    }.toList()..sort();

    final result = <Settlement>[];
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final x = ids[i];
        final y = ids[j];
        final net = (directed[x]?[y] ?? 0) - (directed[y]?[x] ?? 0);
        if (net > 0) {
          result.add(
            Settlement(fromPersonId: x, toPersonId: y, amountCents: net),
          );
        } else if (net < 0) {
          result.add(
            Settlement(fromPersonId: y, toPersonId: x, amountCents: -net),
          );
        }
      }
    }

    result.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return result;
  }
}

class _Node {
  final String id;
  int amount;
  _Node(this.id, this.amount);
}
