/// A person's derived balance across all purchases. All amounts in EUR cents.
class Balance {
  final String personId;
  final int paidCents;
  final int owedCents;

  /// Net effect of recorded settlements on this person: amount they have paid
  /// out minus amount they have received. Reduces their outstanding net.
  /// Zero when no settlements have been recorded.
  final int settledCents;

  const Balance({
    required this.personId,
    required this.paidCents,
    required this.owedCents,
    this.settledCents = 0,
  });

  /// Outstanding net: (paid − owed) adjusted by recorded settlements.
  /// Positive: others owe this person (creditor).
  /// Negative: this person still needs to pay (debtor).
  int get netCents => paidCents - owedCents + settledCents;

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
