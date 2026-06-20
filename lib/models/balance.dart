/// A person's derived balance across all purchases. All amounts in EUR cents.
class Balance {
  final String personId;
  final int paidCents;
  final int owedCents;

  const Balance({
    required this.personId,
    required this.paidCents,
    required this.owedCents,
  });

  /// paid − owed. Positive: others owe this person (creditor).
  /// Negative: this person still needs to pay (debtor).
  int get netCents => paidCents - owedCents;

  bool get isSettled => netCents == 0;
  bool get isCreditor => netCents > 0;
  bool get isDebtor => netCents < 0;
}

/// One payment in the settlement plan: [fromPersonId] pays [toPersonId].
class Settlement {
  final String fromPersonId;
  final String toPersonId;
  final int amountCents;

  const Settlement({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amountCents,
  });
}
